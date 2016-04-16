//
//  ViewController.swift
//  CarLab
//
//  Created by Andrew on 4/10/16.
//  Copyright © 2016 Andrew. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    
    let url = NSURL(string: "http://10.8.198.80:5000")!

    let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    
    let videoImage: UIImageView = UIImageView()
    
    var HTMLString: String = String()
    
    //******************
    // private variables
    //******************

    var motionManager: CMMotionManager!
    var accelTimer: NSTimer!
    
    var lm:CLLocationManager!
    var centerOrientation:CLLocationDirection!
    var readOrientation: Int!
    
    let steeringButton = UIButton(type: UIButtonType.System) as UIButton
    let speedSlider: UISlider = UISlider()
    let steeringSlider: UISlider = UISlider()
    let speedLabel: UILabel = UILabel()
    let steeringImg = UIImageView()
    
    var accelX: String = String()
    var accelY: String = String()
    var accelZ: String = String()
    
    let xLabel: UILabel = UILabel()
    let yLabel: UILabel = UILabel()
    let zLabel: UILabel = UILabel()
    
    let accelImg = UIImageView()
    
    //******************
    // lifecycle methods
    //******************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        videoImage.frame = CGRectMake(0, 0, screenSize.width, screenSize.height)
        videoImage.frame.origin.x = (screenSize.width - videoImage.frame.size.width)*0.5
        videoImage.frame.origin.y = (screenSize.height - videoImage.frame.size.height)*0.5
        self.view.addSubview(videoImage)
        
        let streamingController = MjpegStreamingController(imageView: videoImage)
        // To play url do:
        let url = NSURL(string: "http://80.32.204.149:8080/mjpg/video.mjpg")
        //let url = NSURL(string: "http://10.8.198.80:5000")
        streamingController.play(url: url!)
    
        loadingIndicator.frame = CGRectMake(0, 0, screenSize.width * 0.4, screenSize.width * 0.4)
        loadingIndicator.frame.origin.x = (screenSize.width - loadingIndicator.frame.size.width)*0.5
        loadingIndicator.frame.origin.y = (screenSize.height - loadingIndicator.frame.size.height)*0.5
        loadingIndicator.transform = CGAffineTransformMakeScale(5, 5)
        self.view.addSubview(loadingIndicator)
        
        streamingController.didStartLoading = { [unowned self] in
            self.loadingIndicator.hidden = false
            self.loadingIndicator.startAnimating()
        }
        streamingController.didFinishLoading = { [unowned self] in
            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.hidden = true
        }
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        
//        accelTimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "updateAccelerometerValues", userInfo: nil, repeats: true)
        
        // display accelerometer readings
        let handler: CMDeviceMotionHandler = {(motion: CMDeviceMotion?, error: NSError?) -> Void in
            self.accelImg.frame.origin.y = (screenSize.height - self.accelImg.frame.size.height)/1.8 - ((screenSize.height - self.accelImg.frame.size.height)/2 * CGFloat((motion?.gravity.z)!)*0.9)

            let xGrav = motion?.gravity.x
            let yGrav = motion?.gravity.y
            let zGrav = motion?.gravity.z
            
            self.xLabel.text = "xg: \(xGrav!)"
            self.yLabel.text = "yg: \(yGrav!)"
            self.zLabel.text = "zg: \(zGrav!)"
        }
        
        // check if accelerometer and gyro are available
        if motionManager.deviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01
            // update the accel val readings
            motionManager.startDeviceMotionUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: handler)
        }
        
        lm = CLLocationManager()
        lm.delegate = self
        lm.startUpdatingHeading()
        readOrientation = 0
        
        // refresh button
        let refreshOrientation = UIButton(type: UIButtonType.System) as UIButton
        refreshOrientation.titleLabel!.font = UIFont(name: "ChalkboardSE-Bold", size: 14)
        refreshOrientation.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.height * 0.09)
        refreshOrientation.frame.origin.x = (screenSize.width - refreshOrientation.frame.size.width)*0.9
        refreshOrientation.frame.origin.y = (screenSize.height - refreshOrientation.frame.size.height)*0.1
        refreshOrientation.setTitle("Refresh", forState: UIControlState.Normal)
        let lightBlueColor = UIColor(red: 50/255, green: 70/255, blue: 147/255, alpha: 1.0)
        refreshOrientation.setTitleColor(lightBlueColor, forState: UIControlState.Normal)
        refreshOrientation.addTarget(self, action: "refreshAction:", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(refreshOrientation)
        
        // title label
        let title: UILabel = UILabel()
        title.text = "CarLab 2016"
        title.font = UIFont(name: "Menlo-Bold", size: 30)
        title.frame = CGRectMake(0, 0, screenSize.width*0.42, screenSize.height * 0.1)
        title.frame.origin.x = (screenSize.width - title.frame.size.width)/2
        title.frame.origin.y = (screenSize.height - title.frame.size.height)/20
        self.view.addSubview(title)
        
        // steering slider
        steeringSlider.frame.size.width = screenSize.width*0.4
        steeringSlider.frame.origin.x = (screenSize.width - steeringSlider.frame.size.width)*0.14
        steeringSlider.frame.origin.y = (screenSize.height - steeringSlider.frame.size.height)*0.9
        steeringSlider.addTarget(self, action: "grabbingSteeringSlider:", forControlEvents: UIControlEvents.TouchDragInside)
        steeringSlider.addTarget(self, action: "releaseSteeringSlider:", forControlEvents: UIControlEvents.TouchUpInside)
        steeringSlider.addTarget(self, action: "releaseSteeringSlider:", forControlEvents: UIControlEvents.TouchUpOutside)
        steeringSlider.setValue(0.5, animated: false)
        steeringSlider.maximumTrackTintColor = UIColor.lightGrayColor()
        steeringSlider.minimumTrackTintColor = UIColor.lightGrayColor()
        self.view.addSubview(steeringSlider)
        
        steeringImg.frame = CGRectMake(0, 0, steeringSlider.frame.size.width*0.15, steeringSlider.frame.size.width * 0.15)
        steeringImg.frame.origin.x = steeringSlider.frame.origin.x + steeringSlider.frame.size.width + steeringImg.frame.width/10
        steeringImg.frame.origin.y = (steeringSlider.frame.origin.y - steeringSlider.frame.height/4)
        steeringImg.image = UIImage(named: "straight2")
        self.view.addSubview(steeringImg)
        
        // speed slider
        speedSlider.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI_2))
        speedSlider.frame.size.height = screenSize.height*0.6
        speedSlider.frame.origin.x = (screenSize.width - speedSlider.frame.size.width)*0.9
        speedSlider.frame.origin.y = (screenSize.height - speedSlider.frame.size.height)*0.7
        speedSlider.addTarget(self, action: "grabbingSpeedSlider:", forControlEvents: UIControlEvents.TouchDragInside)
        speedSlider.addTarget(self, action: "releaseSpeedSlider:", forControlEvents: UIControlEvents.TouchUpInside)
        speedSlider.addTarget(self, action: "releaseSpeedSlider:", forControlEvents: UIControlEvents.TouchUpOutside)
        speedSlider.minimumTrackTintColor = UIColor.purpleColor()
        speedSlider.maximumTrackTintColor = UIColor.lightGrayColor()
        self.view.addSubview(speedSlider)
        
        speedLabel.text = "0.0 ft/sec"
        speedLabel.font = UIFont(name: "Menlo", size: 18)
        speedLabel.frame = CGRectMake(0, 0, screenSize.width*0.2, screenSize.height * 0.15)
        speedLabel.frame.origin.x = speedSlider.frame.origin.x - speedSlider.frame.size.width
        speedLabel.frame.origin.y = speedSlider.frame.origin.y + speedSlider.frame.size.height/2 + screenSize.height/3.7
        self.view.addSubview(speedLabel)
        
        accelImg.frame = CGRectMake(0, 0, screenSize.width*0.06, screenSize.width * 0.06)
        accelImg.frame.origin.x = (screenSize.width - accelImg.frame.size.width)*0.5
        accelImg.frame.origin.y = (screenSize.height - accelImg.frame.size.height)*0.5
        accelImg.image = UIImage(named: "circle")
        self.view.addSubview(accelImg)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //******************
    // delegate methods
    //******************
    
    func locationManager(manager: CLLocationManager!, didUpdateHeading newHeading: CLHeading!) {
        if readOrientation == 0 {
            centerOrientation = newHeading.magneticHeading
            readOrientation = 1
            print("\(centerOrientation)")
        }
        var currentOrientation = newHeading.magneticHeading
        if centerOrientation > 180 {
            if currentOrientation < 180 - (360 - centerOrientation) {
                currentOrientation += 360
            }
        }
        else {
            if currentOrientation > 180 + (centerOrientation) {
                currentOrientation -= 360
            }
        }
        let diff = currentOrientation - centerOrientation
        self.accelImg.frame.origin.x = screenSize.width/2 + (screenSize.width/2)*CGFloat(diff/180)*1.2
    }
    
    //******************
    // private methods
    //******************
    
    func refreshAction(sender:UIButton!) {
        readOrientation = 0
    }
    
    func wasDragged (sender : UIButton, event :UIEvent) {
        if let button = sender as? UIButton {
            // get the touch inside the button
            let touch = event.touchesForView(sender)?.first
            // println the touch location
            //print(touch!.locationInView(button))
            let xDist = touch!.locationInView(button).x - button.frame.size.width/2
            steeringButton.frame.origin.x += xDist
        }
        
    }
    
    func grabbingSteeringSlider(sender:UISlider!) {
        if (sender.value > 0.51) {
            sender.minimumTrackTintColor = UIColor.blueColor()
            sender.maximumTrackTintColor = UIColor.redColor()
            steeringImg.image = UIImage(named: "rightturn")
        }
        else if (sender.value < 0.49) {
            sender.minimumTrackTintColor = UIColor.redColor()
            sender.maximumTrackTintColor = UIColor.blueColor()
            steeringImg.image = UIImage(named: "leftturn")
        }
    }
    
    func releaseSteeringSlider(sender:UISlider!) {
        UIView.animateWithDuration(0.4, delay: 0.0, options: .CurveEaseInOut, animations: {
            sender.setValue(0.5, animated: true) },
                                   completion: nil)
        sender.maximumTrackTintColor = UIColor.lightGrayColor()
        sender.minimumTrackTintColor = UIColor.lightGrayColor()
        steeringImg.image = UIImage(named: "straight2")
    }
    
    
    func grabbingSpeedSlider(sender:UISlider!) {
        speedLabel.text = String(format: "%.1f ft/sec", sender.value*5)
    }
    
    func releaseSpeedSlider(sender:UISlider!) {
        UIView.animateWithDuration(0.4, delay: 0.0, options: .CurveEaseInOut, animations: {
            sender.setValue(0.0, animated: true) },
                                   completion: nil)
        speedLabel.text = "0.0 ft/sec"
    }

}

