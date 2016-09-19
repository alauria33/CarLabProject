//
//  MenuViewController.swift
//  CarLab
//
//  Created by Andrew on 4/28/16.
//  Copyright © 2016 Andrew. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

let deepRed = UIColor(red: 208/255, green: 80/255, blue: 80/255, alpha: 1.0)
let darkGray = UIColor(red: 47/255, green: 43/255, blue: 43/255, alpha: 1.0)

class MenuViewController: UIViewController {
    
    let driveButton = UIButton()
    let viewButton = UIButton()

    var driveView: UIViewController = UIViewController()
    var viewerView: UIViewController = UIViewController()

    override func viewDidLoad() {
        
        driveView = storyboard!.instantiateViewControllerWithIdentifier("driveView") as UIViewController
        viewerView = storyboard!.instantiateViewControllerWithIdentifier("viewerView") as UIViewController

        self.view.backgroundColor = deepRed
        
        self.navigationController?.navigationBarHidden = true
        
        let title: UILabel = UILabel()
        title.text = "CarLab 2016"
        title.textAlignment = .Center
        title.textColor = UIColor.whiteColor()
        title.font = UIFont(name: "Menlo-Bold", size: 45)
        title.frame = CGRectMake(0, 0, screenSize.width*0.6, screenSize.height * 0.1)
        title.frame.origin.x = (screenSize.width - title.frame.size.width)/2
        title.frame.origin.y = (screenSize.height - title.frame.size.height)/3.4
        self.view.addSubview(title)
        
        let diff = screenSize.width/5
        driveButton.titleLabel?.font = UIFont(name: "Menlo", size: 30)
        driveButton.backgroundColor = UIColor.whiteColor()
        driveButton.setTitle("Drive", forState: UIControlState.Normal)
        driveButton.setTitleColor(darkGray, forState: UIControlState.Normal)
        driveButton.frame = CGRectMake(0, 0, screenSize.width*0.3, screenSize.height * 0.2)
        driveButton.frame.origin.x = (screenSize.width - driveButton.frame.size.width)/2
        driveButton.frame.origin.y = (screenSize.height - driveButton.frame.size.height)/1.4
        driveButton.layer.cornerRadius = 10
        driveButton.addTarget(self, action: "driveAction:", forControlEvents: UIControlEvents.TouchUpInside)
        driveButton.addTarget(self, action: "driveHeld:", forControlEvents: UIControlEvents.TouchDown)
        driveButton.addTarget(self, action: "driveDragged:", forControlEvents: UIControlEvents.TouchDragExit)
        self.view.addSubview(driveButton)

        
    }
    
    func driveAction(sender:UIButton!) {
        driveButton.alpha = 1.0
        self.navigationController!.pushViewController(driveView, animated: true)
    }
    
    func driveHeld(sender:UIButton!) {
        driveButton.alpha = 0.6
    }
    
    func driveDragged(sender:UIButton!) {
        driveButton.alpha = 1.0
    }
    
}




