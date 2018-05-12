//
//  ConfuseClass.swift
//  ConfuseFW
//
//  Created by Zhang on 2018/5/12.
//  Copyright © 2018年 Zhang. All rights reserved.
//

import Foundation

public class ConfuseClass1 {
    public var var1: String
    private(set) var private_var2: Int
    var private_cls: private_ConfuseClass2
    
    private init(var1: String, var2: Int, cls: private_ConfuseClass2) {
        self.var1 = var1
        self.private_var2 = var2
        self.private_cls = cls
    }

    public convenience init(var1: String, var2: Int) {
        self.init(var1: var1, var2: var2, cls: private_ConfuseClass2())
    }

    public func func1() {
        private_func2()
    }

    func private_func2() {
        print(#function, var1, private_var2, private_cls)
    }
}

class private_ConfuseClass2 {
    var var3: String = "haha"
}
