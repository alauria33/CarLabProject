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
import Foundation

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    let url = NSURL(string: "http://10.8.198.80:5000/video_feed.mjpg")!

    let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    
    let videoImage: UIImageView = UIImageView()
    
    var HTMLString: String = String()
    
    var TempVal: Int = 0
    //******************
    // private variables
    //******************
    
    var pastSpeedVal: Float = 0
    var pastSteeringVal: Float = 0.5
    var pastXServoVal: CGFloat = 90
    var pastYServoVal: CGFloat = 90
    
    var motionManager: CMMotionManager!
    
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
    var previousLocal: CGFloat = CGFloat()
    
    var client:TCPClient = TCPClient()//addr: "192.168.240.1", port: 5678)
    
    var disconnected: Bool = true
    //******************
    // lifecycle methods
    //******************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("leavingApp:"), name:UIApplicationDidEnterBackgroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("leavingApp:"), name:UIApplicationWillTerminateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("enterApp:"), name:UIApplicationDidBecomeActiveNotification, object: nil)

        //client = TCPClient(addr: "192.168.240.1", port: 5678)

        // connect socket
//        var (success, errmsg) = client.connect(timeout: 10)
//        print("connect success: \(success)")
//        if (success) {
//            disconnected = false
//            var (sendSuccess, sendErrmsg) = client.send(str:"Start")
//        }
        
        // Video
        videoImage.frame = CGRectMake(0, 0, screenSize.width, screenSize.height)
        videoImage.frame.origin.x = (screenSize.width - videoImage.frame.size.width)*0.5
        videoImage.frame.origin.y = (screenSize.height - videoImage.frame.size.height)*0.5
        self.view.addSubview(videoImage)
        
        let streamingController = MjpegStreamingController(imageView: videoImage)
        // To play url do:
        let url = NSURL(string: "http://10.8.198.80:5000/video_feed.mjpg")
        //let url = NSURL(string: "http://10.8.198.80:5000")
        streamingController.play(url: url!)
        
        loadingIndicator.frame = CGRectMake(0, 0, screenSize.width * 0.4, screenSize.width * 0.4)
        loadingIndicator.frame.origin.x = (screenSize.width - loadingIndicator.frame.size.width)*0.5
        loadingIndicator.frame.origin.y = (screenSize.height - loadingIndicator.frame.size.height)*0.5
        loadingIndicator.transform = CGAffineTransformMakeScale(5, 5)
        //self.view.addSubview(loadingIndicator)
        
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

        // vertical motion
        let handler: CMDeviceMotionHandler = {(motion: CMDeviceMotion?, error: NSError?) -> Void in
            self.accelImg.frame.origin.y = (screenSize.height - self.accelImg.frame.size.height)/1.8 - ((screenSize.height - self.accelImg.frame.size.height)/2 * CGFloat((motion?.gravity.z)!)*0.9)

            if !self.disconnected {
                let yValue: CGFloat = (1 - (self.accelImg.frame.origin.y/screenSize.height)) * 180
                if (yValue - self.pastYServoVal > 1 || yValue - self.pastYServoVal < -1) {
                    var (sendSuccess, sendErrmsg) = self.client.send(str:"yServo\(yValue)")
                    print("\(yValue) \(sendSuccess)")
                    self.pastYServoVal = yValue
                }
            }
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
        refreshOrientation.frame.origin.x = (screenSize.width - refreshOrientation.frame.size.width)*0.96
        refreshOrientation.frame.origin.y = (screenSize.height - refreshOrientation.frame.size.height)*0.1
        refreshOrientation.setTitle("Refresh", forState: UIControlState.Normal)
        let lightBlueColor = UIColor(red: 50/255, green: 70/255, blue: 147/255, alpha: 1.0)
        refreshOrientation.setTitleColor(lightBlueColor, forState: UIControlState.Normal)
        refreshOrientation.addTarget(self, action: "refreshAction:", forControlEvents: UIControlEvents.TouchUpInside)
        //self.view.addSubview(refreshOrientation)
        
        // refresh button
        let startButton = UIButton(type: UIButtonType.System) as UIButton
        startButton.titleLabel!.font = UIFont(name: "ChalkboardSE-Bold", size: 14)
        startButton.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.height * 0.09)
        startButton.frame.origin.x = (screenSize.width - startButton.frame.size.width)*0.8
        startButton.frame.origin.y = (screenSize.height - startButton.frame.size.height)*0.1
        startButton.setTitle("Start", forState: UIControlState.Normal)
        startButton.setTitleColor(lightBlueColor, forState: UIControlState.Normal)
        startButton.addTarget(self, action: "startConnection:", forControlEvents: UIControlEvents.TouchUpInside)
        //self.view.addSubview(startButton)
        // refresh button
        let stopButton = UIButton(type: UIButtonType.System) as UIButton
        stopButton.titleLabel!.font = UIFont(name: "ChalkboardSE-Bold", size: 14)
        stopButton.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.height * 0.09)
        stopButton.frame.origin.x = (screenSize.width - stopButton.frame.size.width)*0.7
        stopButton.frame.origin.y = (screenSize.height - stopButton.frame.size.height)*0.1
        stopButton.setTitle("Stop", forState: UIControlState.Normal)
        stopButton.setTitleColor(lightBlueColor, forState: UIControlState.Normal)
        stopButton.addTarget(self, action: "stopConnection:", forControlEvents: UIControlEvents.TouchUpInside)
        //self.view.addSubview(stopButton)
        
        // title label
        let title: UILabel = UILabel()
        title.text = "CarLab 2016"
        title.font = UIFont(name: "Menlo-Bold", size: 30)
        title.frame = CGRectMake(0, 0, screenSize.width*0.42, screenSize.height * 0.1)
        title.frame.origin.x = (screenSize.width - title.frame.size.width)/2
        title.frame.origin.y = (screenSize.height - title.frame.size.height)/20
        //,.self.view.addSubview(title)
        
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
        //self.view.addSubview(accelImg)
        
        let imgDiff = screenSize.width/5
        
        var leftImage: UIImageView = UIImageView()
        leftImage.frame = CGRectMake(0, 0, screenSize.width/3, screenSize.height/2.8)
        leftImage.frame.origin.x = (screenSize.width - leftImage.frame.size.width)*0.5 - imgDiff
        leftImage.frame.origin.y = (screenSize.height - leftImage.frame.size.height)*0.5
        leftImage.image = UIImage(named: "taco.png")
        self.view.addSubview(leftImage)
        
        var rightImage: UIImageView = UIImageView()
        rightImage.frame = CGRectMake(0, 0, screenSize.width/3, screenSize.height/2.8)
        rightImage.frame.origin.x = (screenSize.width - rightImage.frame.size.width)*0.5 + imgDiff
        rightImage.frame.origin.y = (screenSize.height - rightImage.frame.size.height)*0.5
        rightImage.image = UIImage(named: "taco.png")
        self.view.addSubview(rightImage)
        
        var cardBoardView: UIImageView = UIImageView()
        cardBoardView.frame = CGRectMake(0, 0, screenSize.width, screenSize.height)
        cardBoardView.frame.origin.x = (screenSize.width - cardBoardView.frame.size.width)*0.5
        cardBoardView.frame.origin.y = (screenSize.height - cardBoardView.frame.size.height)*0.5
        cardBoardView.image = UIImage(named: "cardboard.png")
        self.view.addSubview(cardBoardView)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //******************
    // delegate methods
    //******************
    
    // horizontal motion
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
        let xLocal = (screenSize.width/2 + (screenSize.width/2)*CGFloat(diff/180)*1.2)
        self.accelImg.frame.origin.x = xLocal
        
        if !disconnected {
            let xValue: CGFloat = (1 - (accelImg.frame.origin.x/screenSize.width)) * 180
            if (xValue - pastXServoVal > 1 || xValue - pastXServoVal < -1) {
                var (sendSuccess, sendErrmsg) = client.send(str:"xServo\(xValue)")
                print("\(xValue) \(sendSuccess)")
                pastXServoVal = xValue
            }
        }
        
    }
    
    //******************
    // private methods
    //******************
    
    func refreshAction(sender:UIButton!) {
        readOrientation = 0

        if TempVal == 180 {
            TempVal = 0
        }
        else {
            TempVal += 10
        }

    }
    
    func startConnection(sender:UIButton!) {
        if disconnected {
            var (success, errmsg) = client.connect(timeout: 10)
            print("connect success: \(success)")
            disconnected = false
        }
    }
    
    func stopConnection(sender:UIButton!) {
        var (success, errmsg) = client.send(str:"stop")
        print("disconnect success: \(success)")
        disconnected = true
    }
    
    func leavingApp(sender: AnyObject!) {
        print("leaving App")
        var (success, errmsg) = client.send(str:"stop")
        print("disconnect success: \(success)")
        disconnected = true
    }
    
    func enterApp(sender: AnyObject!) {
        print("entering App")
        if disconnected {
            var (success, errmsg) = client.connect(timeout: 10)
            print("connect success: \(success)")
            disconnected = false
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
        
        if !disconnected {
            if (pastSteeringVal - steeringSlider.value > 0.02 || pastSteeringVal - steeringSlider.value < -0.02) {
                let steeringVal = Int(((steeringSlider.value) * 142.8) + 127.5)
                if steeringVal > 255 {
                    var (sendSuccess, sendErrmsg) = client.send(str:"steer/254")
                }
                else {
                    var (sendSuccess, sendErrmsg) = client.send(str:"steer/\(steeringVal)")
                }
                pastSteeringVal =  steeringSlider.value
            }
        }
        
    }
    
    func releaseSteeringSlider(sender:UISlider!) {
        UIView.animateWithDuration(0.4, delay: 0.0, options: .CurveEaseInOut, animations: {
            sender.setValue(0.5, animated: true) },
                                   completion: nil)
        sender.maximumTrackTintColor = UIColor.lightGrayColor()
        sender.minimumTrackTintColor = UIColor.lightGrayColor()
        steeringImg.image = UIImage(named: "straight2")
        
        if !disconnected {
            var (sendSuccess, sendErrmsg) = client.send(str:"steer/198.9")
            pastSteeringVal =  0.5
        }
    }
    
    
    func grabbingSpeedSlider(sender:UISlider!) {
        if (sender.value > 0.1) {
            speedLabel.text = String(format: "%.1f ft/sec", 1.5 + (sender.value-0.1)*7.22222)
        }
        else {
            speedLabel.text = String(format: "%.1f ft/sec", 0.0)
        }
        if !disconnected {
            if (pastSpeedVal - speedSlider.value > 0.02 || pastSpeedVal - speedSlider.value < -0.02) {
                let speedVal = Int(((speedSlider.value) * 253) + 1)
                var (sendSuccess, sendErrmsg) = client.send(str:"speed/\(speedVal)")
                pastSpeedVal =  speedSlider.value
            }
        }
    }
    
    func releaseSpeedSlider(sender:UISlider!) {
        UIView.animateWithDuration(0.4, delay: 0.0, options: .CurveEaseInOut, animations: {
            sender.setValue(0.0, animated: true) },
                                   completion: nil)
        speedLabel.text = "0.0 ft/sec"
        
        if !disconnected {
            var (sendSuccess, sendErrmsg) = client.send(str:"speed/1")
            pastSpeedVal =  0
        }
    }

}

