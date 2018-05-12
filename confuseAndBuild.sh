#!/bin/sh

#  confuse.sh
#  OADHelper
#
#  Created by Jonor on 2018/4/28.
#  Copyright © 2018年 SOUNDMAX. All rights reserved.

if [ -z "$PROJECT_NAME" ]; then
    echo "未配置完整环境变量，请用Xcode运行该脚本"
    exit
else
    CONFUSE_DIR="${SRCROOT}/${PROJECT_NAME}"
fi
CONFUSE_PREFIX="private_"
BACKUP_TYPE="bak"
SOURCE_TYPE="swift"
CONFUSE_SYMBOL_FILE="${SRCROOT}/.symbol.log"
CONFUSE_FILE="${SRCROOT}/.confuse.log"
CONFUSE_FLAG="${SRCROOT}/.confuseFlag"

# 备份文件 $1:file full path
backupFile() {
    file=$1
    backup=`echo $file | sed "s:\([^/]*.$SOURCE_TYPE\):.&.$BACKUP_TYPE:g"`
    echo $backup

    if [ ! -f $backup ]; then
        cp $file $backup
    fi
}

# 方案1. 精确备份：用关键字遍历会修改到的swift文件，再将其备份 -- 消耗性能
# 方案2. 整体备份：备份所有swift文件 -- 消耗存储空间
# 根据需要，为简单起见，这里选用方案2
backupAllSwift() {
    echo "backup all swift files"
    swiftFiles=`find $CONFUSE_DIR -name *.$SOURCE_TYPE`
    for file in $swiftFiles; do
        echo
        backupFile $file
    done
}

# 生成随机字符串 16字
randomString() {
    openssl rand -base64 64 | tr -cd 'a-zA-Z' | head -c 16
}

# 获取符号的随机字符串  $1是符号名
randomStringWithSymbol() {
    grep -w $1 $CONFUSE_SYMBOL_FILE -h | cut -d \  -f 2
}

info() {
    local green="\033[1;32m"
    local normal="\033[0m"
    echo "[${green}info${normal}] $1"
}

removeIfExist() {
    if [ -f $1 ]; then
        rm $1
    fi
}

# 混淆工作， ⚠️该函数不会自动备份，要备份请调用safeConfuse函数
confuseOnly() {
    info "confuse start..."

    # 获取要混淆的函数名和变量名
    grep $CONFUSE_PREFIX -r $CONFUSE_DIR --include="*.$SOURCE_TYPE" -n >$CONFUSE_FILE

    # 绑定随机字符串
    removeIfExist $CONFUSE_SYMBOL_FILE
    touch $CONFUSE_SYMBOL_FILE
    #cat $CONFUSE_FILE | sed "s/.*\($CONFUSE_PREFIX[0-9a-zA-Z_]*\).*/\1/g" | sort | while read line; do
    cat $CONFUSE_FILE | egrep "$CONFUSE_PREFIX[0-9a-zA-Z_]*" -o | sort | uniq | while read line; do
        echo $line" `randomString`" >>$CONFUSE_SYMBOL_FILE
    done

    cat $CONFUSE_SYMBOL_FILE

    # 读取备份文件记录
    # 在这里没使用遍历批量替换，怕文件太多的时候影响性能
    cat $CONFUSE_FILE | while read line; do
        # 行号
        lineNum=`echo $line | sed 's/.*:\([0-9]*\):.*/\1/g'`
        # 文件路径
        path=${line%%:*}
        # 一行可能有多个要替换的子串
        echo $line | egrep "$CONFUSE_PREFIX[0-9a-zA-Z_]*" -o | while read -ra symbol; do
            # 绑定随机字符串
            random=`randomStringWithSymbol $symbol`
#            echo "$path $lineNum $symbol $random"
            # 随机字符串替换
            sed -i "" "${lineNum}s/$symbol/$random/g" $path
        done
    done

    info "confuse done"
}

# 编译工作，生成通用framework
buildAll() {
    info "build start..."

    # 要build的target名
    TARGET_NAME=${PROJECT_NAME}
    UNIVERSAL_OUTPUT_DIR="${SRCROOT}/Framework/"

    # 创建输出目录，并删除之前的framework文件
    mkdir -p "${UNIVERSAL_OUTPUT_DIR}"
    rm -rf "${UNIVERSAL_OUTPUT_DIR}/${TARGET_NAME}.framework"

    #分别编译模拟器和真机的Framework
    xcodebuild -target "${TARGET_NAME}" ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} ARCHS="armv7 armv7s arm64" -sdk iphoneos BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build
    xcodebuild -target "${TARGET_NAME}" ONLY_ACTIVE_ARCH=NO -configuration ${CONFIGURATION} ARCHS="i386 x86_64" -sdk iphonesimulator BUILD_DIR="${BUILD_DIR}" BUILD_ROOT="${BUILD_ROOT}" clean build

    #拷贝framework到univer目录
    cp -R "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${TARGET_NAME}.framework" "${UNIVERSAL_OUTPUT_DIR}"

    # 合并swiftmodule到univer目录
    cp -R "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${TARGET_NAME}.framework/Modules/${TARGET_NAME}.swiftmodule/" "${UNIVERSAL_OUTPUT_DIR}/${TARGET_NAME}.framework/Modules/${TARGET_NAME}.swiftmodule"

    #合并framework，输出最终的framework到build目录
    lipo -create -output "${UNIVERSAL_OUTPUT_DIR}/${TARGET_NAME}.framework/${TARGET_NAME}" "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${TARGET_NAME}.framework/${TARGET_NAME}" "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${TARGET_NAME}.framework/${TARGET_NAME}"

    #删除编译之后生成的无关的配置文件
    dir_path="${UNIVERSAL_OUTPUT_DIR}/${TARGET_NAME}.framework/"
    for file in ls $dir_path; do
        if [[ ${file} =~ ".xcconfig" ]]; then
            rm -f "${dir_path}/${file}"
        fi
    done

    #判断build文件夹是否存在，存在则删除
    if [ -d "${SRCROOT}/build" ]; then
        rm -rf "${SRCROOT}/build"
    fi

    #rm -rf "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator" "${BUILD_DIR}/${CONFIGURATION}-iphoneos"

    #打开合并后的文件夹
    open "${UNIVERSAL_OUTPUT_DIR}"

    info "build done"
}

# 清理工作，去混淆
unconfuse() {
    info "clean start..."

    # 恢复混淆的函数名所在swift文件的bak内容
    backups=`find $CONFUSE_DIR -name "*.$BACKUP_TYPE"`
    for backup in $backups; do
        file=`echo $backup | sed "s:.\([^.]*.$SOURCE_TYPE\).$BACKUP_TYPE:\1:g"`
        echo $file
        cp $backup $file
        rm $backup
    done

    # 删除修改记录
    removeIfExist $CONFUSE_SYMBOL_FILE
    removeIfExist $CONFUSE_FILE
    removeIfExist $CONFUSE_FLAG

    info "clean done"
}

# 检查是否上次未完成
precheck() {
    # 创建一个隐藏文件，仅标记混淆编译的状态
    # 由于编译过程有可能被中断，因此混淆后的代码可能未恢复，在开始备份前先做判断
    if [ ! -f $CONFUSE_FLAG ]; then
        touch $CONFUSE_FLAG
    else
        unconfuse
    fi
}

# 去混淆->备份->混淆
safeConfuse() {
    precheck
    backupAllSwift
    confuseOnly
}

# 去混淆->备份->混淆
# 编译
# 去混淆
safeConfuseAndBuild() {
    info "preparing confuse and build..."

    safeConfuse
    buildAll
    unconfuse

    info "all done"
}

