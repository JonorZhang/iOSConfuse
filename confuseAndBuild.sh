#!/bin/bash

#  confuseAndBuild.sh
#  ConfuseSwift
#
#  Created by Jonor on 2018/4/28.
#  Copyright © 2018年 Zhang. All rights reserved.

# ⚠️声明
# 1. 请将该脚本放在Xcode工程的根目录。
# 2. 当前版本未配置完整Xcode环境变量，仅支持混淆功能，不支持framework编译，若需编译请用Xcode运行该脚本。
# 3. PS：下一版更新会支持在终端运行脚本。

# 认为定义了‘PROJECT_NAME’的是从Xcode运行，未定义则是从终端运行
if [ -z "$PROJECT_NAME" ]; then
    CONFUSE_DIR="."
else
    CONFUSE_DIR="${SRCROOT}/${PROJECT_NAME}"
fi

CONFUSE_PREFIX="private_"

BACKUP_FILE=".backup.log"
SYMBOL_FILE=".symbol.log"
CONFUSE_FILE=".confuse.log"
CONFUSE_FLAG=".confuseFlag"

SOURCE_ARRAY=( "*.swift" 
                "*.m" 
                "*.h" 
                "*.c" 
                "*.cpp")
BACKUP_EXTENSION=".bak"


# 格式：echo -e "\033[背景色;前景色m 打印的字符串 \033[0m" 
# 颜色：重置=0，黑色=30，红色=31，绿色=32，黄色=33，蓝色=34，洋红=35，青色=36，白色=37。
# 示例：echo -e “\033[30m 我是黑色字 \033[0m” 
# 参考：https://www.cnblogs.com/xiansong1005/p/7221316.html
#      https://www.cnblogs.com/lr-ting/archive/2013/02/28/2936792.html
info() {
    local green="\033[1;32m"
    local normal="\033[0m"
    echo -e "[${green}info${normal}] $1"
}

error() {
    local red="\033[1;31m"
    local normal="\033[0m"
    echo -e "[${red}error${normal}] $1"
}

# 生成随机字符串 16字
randomString() {
    openssl rand -base64 64 | tr -cd 'a-zA-Z' | head -c 16
}

# 获取符号的随机字符串  $1是符号名
randomStringWithSymbol() {
    grep -w $1 $SYMBOL_FILE -h | cut -d \  -f 2
}

removeIfExist() {
    if [ -f $1 ]; then
        rm $1
    fi
}

# 备份文件 $1:file full path
backupFile() {
    file=$1
    # 在原文件名前加个.（点符合）用作备份名
    fileName=${file##*/}
    backupPath=${file/$fileName/.$fileName$BACKUP_EXTENSION}
    echo "backup $file to $backupPath"

    if [ ! -f $backupPath ]; then
        cp $file $backupPath
        echo $backupPath >>$BACKUP_FILE
    fi
}

# 方案1. 精确备份：用关键字遍历会修改到的source文件，再将其备份 -- 消耗性能
# 方案2. 整体备份：备份所有source文件 -- 消耗存储空间
# 根据需要，为简单起见，这里选用方案2
backupAllSource() {
    info "backup all swift files"
    NAMES="-name \"${SOURCE_ARRAY[0]}\""
    i=1
    while [ $i -lt ${#SOURCE_ARRAY[@]} ]; do  
        NAMES+=" -or -name \"${SOURCE_ARRAY[$i]}\""
        let i++
    done
    # echo $NAMES

    removeIfExist $BACKUP_FILE
    touch $BACKUP_FILE
    
    eval "find $CONFUSE_DIR $NAMES" | while read file; do
        backupFile $file
    done
}

# 混淆工作， ⚠️该函数不会自动备份，要备份请调用safeConfuse函数
confuseOnly() {
    info "confuse start..."

    # 获取要混淆的函数名和变量名
    INCLUDES="--include=\"${SOURCE_ARRAY[0]}\""
    i=1
    while [ $i -lt ${#SOURCE_ARRAY[@]} ]; do  
        INCLUDES+=" --include=\"${SOURCE_ARRAY[$i]}\""
        let i++    
    done
    eval "grep $CONFUSE_PREFIX -r $CONFUSE_DIR $INCLUDES -n" >$CONFUSE_FILE

    # cat $CONFUSE_FILE
    # 绑定随机字符串
    removeIfExist $SYMBOL_FILE
    touch $SYMBOL_FILE
    
    cat $CONFUSE_FILE | egrep -w $CONFUSE_PREFIX"[0-9a-zA-Z_]*" -o | sort | uniq | while read line; do
        echo $line" `randomString`" >>$SYMBOL_FILE
    done

    # cat $SYMBOL_FILE

    # 读取备份文件记录
    # 在这里没使用遍历批量替换，怕文件太多的时候影响性能
    cat $CONFUSE_FILE | while read line; do
#        echo "> $line"
        # 截取行号
        lineNum=`echo $line | sed 's/.*:\([0-9]*\):.*/\1/g'`
        # 截取文件路径
        path=${line%%:*}
        
        # 一行可能有多个要替换的子串，要循环遍历完
        # 这里之所以要用`sort -r`倒序是因为有个bug：如有字符串"jjyy abc hello abcde", 现在要替换"abc"为"123"（abcde保持不变），也就是传说中的‘全匹配替换’，
        # 但不知为何在macOS下单词边界表达式不起作用：\<abc\> 或者 \babc\b都不起作用，Linux下这个正则表达式是没问题的。
        # 倒序之后有长串优先替换长串，防止短串把长串部分替换掉。但依然存在bug：若是长串不需要替换，则短串替换是依然会将长串部分替换😂
        # 因此依然还需要寻找macOS下单词边界/全匹配 的正则表达式
        echo $line | egrep -w $CONFUSE_PREFIX"[0-9a-zA-Z_]*" -o | sort -r | while read -ra symbol; do
            # 根据名称获取绑定的随机字符串
            random=`randomStringWithSymbol $symbol`
#            echo "$path $lineNum $symbol $random"
            # 随机字符串替换
            # -i：表示直接在原文件替换，""：表示不要备份
            sed -i "" "${lineNum}s/$symbol/$random/g" $path 

            echo "  $symbol => $random"
        done
    done

    info "confuse done"
}

# 编译工作，生成通用framework
buildAll() {
    info "build start..."
    
    if [ -z "$PROJECT_NAME" ]; then
        echo -e "\033[1;31mERROR：当前版本未配置完整Xcode环境变量，仅支持混淆功能，不支持framework编译，若需编译请用Xcode运行该脚本\033[0m"
        return
    fi

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
    if [ -f $CONFUSE_FLAG ]; then
        # 恢复混淆的函数名所在source文件的bak内容
        cat $BACKUP_FILE | while read backup; do
            backupName=${backup##*/}
            fileName=`echo $backupName | cut -d "." -f2,3`
            filePath=${backup/$backupName/$fileName}
            
            echo "recover $backup to $filePath"

            cp $backup $filePath
            rm $backup
        done
        # 删除修改记录
        removeIfExist $SYMBOL_FILE
        removeIfExist $CONFUSE_FILE
        removeIfExist $BACKUP_FILE
        removeIfExist $CONFUSE_FLAG
    else
        echo "Not confuse yet!"
    fi
    info "clean done"
}

# 检查是否上次未完成
precheck() {
    # 创建一个隐藏文件，仅标记混淆编译的状态
    # 由于编译过程有可能被中断，因此混淆后的代码可能未恢复，在开始备份前先做判断
    unconfuse        
    touch $CONFUSE_FLAG
}

# 去混淆->备份->混淆
safeConfuse() {
    precheck
    backupAllSource
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

usage() {
    echo -e "\033[1;31musage: ./confuseAndBuild.sh [-u|c|b|a]"
    echo -e "  -u"
    echo -e "      unconfuse: 清理工作，去混淆"
    echo -e "  -c"
    echo -e "      safeConfuse: 去混淆->备份->混淆"
    echo -e "  -b"
    echo -e "      buildAll: 编译生成通用framework"    
    echo -e "  -a"
    echo -e "      safeConfuseAndBuild: 去混淆->备份->混淆->编译->去混淆"
    echo -e "EXAMPLE:"
    echo -e "  ./confuseAndBuild.sh -u\033[0m"
}

main() {
    echo "参数个数：$#  参数值:$1"
    case $1 in
    "-u" )
        unconfuse
        ;;
    "-c" )
        safeConfuse
        ;;
    "-b" )
        buildAll
        ;;
    "-a" )
        safeConfuseAndBuild
        ;;
    * )
        usage
        ;;
    esac
}

main $@

