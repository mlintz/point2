//
//  UIButton+Util.swift
//  point2
//
//  Created by Mikey Lintz on 10/21/17.
//  Copyright © 2017 Mikey Lintz. All rights reserved.
//

import UIKit

extension UIButton {
  func setBackgroundColor(color: UIColor, for state: UIControlState) {
    let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
    UIGraphicsBeginImageContext(rect.size);
    let context = UIGraphicsGetCurrentContext()!;
    context.setFillColor(color.cgColor);
    //  [[UIColor colorWithRed:222./255 green:227./255 blue: 229./255 alpha:1] CGColor]) ;
    context.fill(rect)
    let img = UIGraphicsGetImageFromCurrentImageContext()!;
    UIGraphicsEndImageContext();
    setBackgroundImage(img, for: state)
  }
}
