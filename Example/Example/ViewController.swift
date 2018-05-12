//
//  ViewController.swift
//  Example
//
//  Created by Zhang on 2018/5/12.
//  Copyright © 2018年 Zhang. All rights reserved.
//

import UIKit
import ConfuseFW

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let cfs = ConfuseClass1.init(var1: "hello~", var2: 100)
        cfs.var1 = "hi~"
        cfs.func1()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

