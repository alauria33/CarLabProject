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
import AVFoundation
import MediaPlayer
import AudioToolbox

class VRViewController: UIViewController, CLLocationManagerDelegate {
    
    let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    
    let videoImage: UIImageView = UIImageView()
    var streamingController: MjpegStreamingController!
    let videoUrl = NSURL(string: "http://10.9.146.228:8080/?action=stream")
    
    var HTMLString: String = String()
    
    var TempVal: Int = 0
    //******************
    // private variables
    //******************
    
    var pastSpeedVal: Float = 0
    var pastSteeringVal: Float = 0.5
    var pastXServoVal: Double = 90
    var pastYServoVal: Double = 75
    
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
    
    var trueHeading: Bool = true
    var quaternion: CMQuaternion = CMQuaternion()
    
    var tilt: Double = 0.0
    
    var orientationDiff: CLLocationDirection = CLLocationDirection()
    var zGravity: Double = Double()
    
    var startVolume: Float = Float()
    let volumeView = MPVolumeView()
    
    let alertImg: UIImageView = UIImageView()
    
    var allowVibration: Bool = true
    var animateTimer: NSTimer = NSTimer()
    var vibrationTimer: NSTimer = NSTimer()
    var vibrationCount: Int = 0
    var alertCount: Int = 0
    
    //******************
    // lifecycle methods
    //******************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.view.backgroundColor = UIColor.whiteColor()//deepRed
        
        let volumeView: MPVolumeView = MPVolumeView()
        volumeView.hidden = false
        volumeView.sizeToFit()
        volumeView.frame = CGRectMake(screenSize.width, screenSize.height, 0, 0)
        self.view.addSubview(volumeView)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("leavingApp:"), name:UIApplicationDidEnterBackgroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("leavingApp:"), name:UIApplicationWillTerminateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("enterApp:"), name:UIApplicationDidBecomeActiveNotification, object: nil)
        
        let servoTimer = NSTimer.scheduledTimerWithTimeInterval(0.035, target: self, selector: "updateServos", userInfo: nil, repeats: true)
        
        let readTimer = NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: "readData", userInfo: nil, repeats: true)
        
        // Video
        let videoSize = 1
        if videoSize == 0 {
            videoImage.frame.size.height = screenSize.height
            videoImage.frame.size.width = videoImage.frame.size.height * (4/3)
        }
        else {
            videoImage.frame.size.width = screenSize.width
            videoImage.frame.size.height = videoImage.frame.size.width * (3/4)
        }
        
        videoImage.frame.origin.x = (screenSize.width - videoImage.frame.size.width)*0.5
        videoImage.frame.origin.y = (screenSize.height - videoImage.frame.size.height)*0.5
        self.view.addSubview(videoImage)
        
        streamingController = MjpegStreamingController(imageView: videoImage)
        
        if autoStart {
            client = TCPClient(addr: "10.9.146.228", port: 5678)
            // connect socket
            var (success, errmsg) = client.connect(timeout: 10)
            print("connect success: \(success)")
            if (success) {
                disconnected = false
                var (sendSuccess, sendErrmsg) = client.send(str:"Start")
            }
            streamingController.play(url: videoUrl!)
            print("done vid")
        }
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        // vertical motion
        let handler: CMDeviceMotionHandler = {(motion: CMDeviceMotion?, error: NSError?) -> Void in
            self.zGravity = (motion?.gravity.z)!
        }
        
        // check if accelerometer and gyro are available
        if motionManager.deviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01
            // update the accel val readings
            motionManager.startDeviceMotionUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: handler)
        }
        
        lm = CLLocationManager()
        lm.headingOrientation = CLDeviceOrientation.LandscapeLeft
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
        self.view.addSubview(refreshOrientation)
        
        // refresh button
        let startButton = UIButton(type: UIButtonType.System) as UIButton
        startButton.titleLabel!.font = UIFont(name: "ChalkboardSE-Bold", size: 14)
        startButton.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.height * 0.09)
        startButton.frame.origin.x = (screenSize.width - startButton.frame.size.width)*0.8
        startButton.frame.origin.y = (screenSize.height - startButton.frame.size.height)*0.1
        startButton.setTitle("Start", forState: UIControlState.Normal)
        startButton.setTitleColor(lightBlueColor, forState: UIControlState.Normal)
        startButton.addTarget(self, action: "startConnection:", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(startButton)
        
        // refresh button
        let stopButton = UIButton(type: UIButtonType.System) as UIButton
        stopButton.titleLabel!.font = UIFont(name: "ChalkboardSE-Bold", size: 14)
        stopButton.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.height * 0.09)
        stopButton.frame.origin.x = (screenSize.width - stopButton.frame.size.width)*0.7
        stopButton.frame.origin.y = (screenSize.height - stopButton.frame.size.height)*0.1
        stopButton.setTitle("Stop", forState: UIControlState.Normal)
        stopButton.setTitleColor(lightBlueColor, forState: UIControlState.Normal)
        stopButton.addTarget(self, action: "stopConnection:", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(stopButton)
        
        let backArrow = UIButton(type: UIButtonType.System) as UIButton
        backArrow.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.width * 0.12)
        backArrow.frame.origin.x = (screenSize.width - stopButton.frame.size.width)*0.04
        backArrow.frame.origin.y = (screenSize.height - stopButton.frame.size.height)*0.04
        backArrow.setImage(UIImage(named: "leftarrow.png"), forState: UIControlState.Normal)
        backArrow.addTarget(self, action: "back:", forControlEvents: UIControlEvents.TouchUpInside)
        backArrow.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        backArrow.tintColor = UIColor.blackColor()
        self.view.addSubview(backArrow)
        
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
        //self.view.addSubview(leftImage)
        
        var rightImage: UIImageView = UIImageView()
        rightImage.frame = CGRectMake(0, 0, screenSize.width/3, screenSize.height/2.8)
        rightImage.frame.origin.x = (screenSize.width - rightImage.frame.size.width)*0.5 + imgDiff
        rightImage.frame.origin.y = (screenSize.height - rightImage.frame.size.height)*0.5
        rightImage.image = UIImage(named: "taco.png")
        //self.view.addSubview(rightImage)
        
        var cardBoardView: UIImageView = UIImageView()
        cardBoardView.frame = CGRectMake(0, 0, screenSize.width, screenSize.height)
        cardBoardView.frame.origin.x = (screenSize.width - cardBoardView.frame.size.width)*0.5
        cardBoardView.frame.origin.y = (screenSize.height - cardBoardView.frame.size.height)*0.5
        cardBoardView.image = UIImage(named: "cardboard.png")
        //self.view.addSubview(cardBoardView)
        
        listenVolumeButton()
        
        alertImg.frame = CGRectMake(0, 0, screenSize.width*0.25, screenSize.width * 0.23)
        alertImg.frame.origin.x = (screenSize.width - alertImg.frame.size.width)*0.5
        alertImg.frame.origin.y = (screenSize.height - alertImg.frame.size.height)*0.5
        alertImg.image = UIImage(named: "alert")
        
        
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
        var tiltDiff: Double = 0.0
        if tilt < 0 {
            tiltDiff = 0.5 - abs(-0.5 - tilt)
        }
        else if tilt > 0 {
            tiltDiff = 0.5 - abs(0.5 - tilt)
        }
        //print(tiltDiff)
        var fixed = (newHeading.trueHeading - (tilt*90))%360
        if fixed < 0 {
            fixed += 360
        }
        //print("mag: \(newHeading.trueHeading) , tilt: \(tilt) , fixed: \(fixed))")
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
        orientationDiff = currentOrientation - centerOrientation
        
    }
    
    //******************
    // private methods
    //******************
    
    func back(sender:UIButton!) {
        self.navigationController?.popToRootViewControllerAnimated(true)
    }
    
    func refreshAction(sender:UIButton!) {
        readOrientation = 0
        trueHeading = !trueHeading
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
            streamingController.play(url: videoUrl!)
        }
    }
    
    func stopConnection(sender:UIButton!) {
        var (success, errmsg) = client.send(str:"stop/")
        print("disconnect success: \(success)")
        disconnected = true
        streamingController.stop()
    }
    
    func leavingApp(sender: AnyObject!) {
        print("leaving App")
        var (success, errmsg) = client.send(str:"stop/")
        print("disconnect success: \(success)")
        disconnected = true
        streamingController.stop()
    }
    
    func enterApp(sender: AnyObject!) {
        print("entering App")
        if disconnected {
            var (success, errmsg) = client.connect(timeout: 10)
            print("connect success: \(success)")
            disconnected = false
            streamingController.play(url: videoUrl!)
            listenVolumeButton()
        }
    }
    
    func readData() {
        var (sendSuccess, sendErrmsg) = client.send(str:"r/0")
        if sendSuccess {
            let data1 = client.read(1024*10)
            var val1: [UInt8] = [0]
            var val2: [UInt8] = [0]
            var byteArray : [UInt8] = [0, 0, 0, 0]
            if let d1 = data1 {
                byteArray[3] = d1[0]
            }
            let data2 = client.read(1024*10)
            if let d2 = data2 {
                byteArray[2] = d2[0]
            }
            var value = byteArray.withUnsafeBufferPointer({
                UnsafePointer<UInt32>($0.baseAddress).memory
            })
            value = UInt32(bigEndian: value)
            print(value)
            if allowVibration && value < 1200 {
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                vibrationTimer  = NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "vibrate", userInfo: nil, repeats: true)
                allowVibration = false
                self.view.addSubview(alertImg)
                UIView.animateWithDuration(1, animations: { () -> Void in
                    self.alertImg.transform = CGAffineTransformMakeScale(1.5, 1.5)
                }) { (finished: Bool) -> Void in
                    UIView.animateWithDuration(1, animations: { () -> Void in
                        self.alertImg.transform = CGAffineTransformIdentity
                    })}
                animateTimer = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: "animateAlert", userInfo: nil, repeats: true)
                alertCount = 0
            }
            else if !allowVibration && value > 1400 {
                alertCount++
            }
            if alertCount == 3 {
                alertImg.removeFromSuperview()
                animateTimer.invalidate()
                allowVibration = true
                alertCount = 0
            }
        }
    }
    
    func updateServos() {
        var ardX = 83 - (orientationDiff * (166/200))
        if ardX < 0 {
            ardX = 0
        }
        else if ardX > 166 {
            ardX = 166
        }
        ardX = round(100 * ardX) / 100
        self.accelImg.frame.origin.x = -self.accelImg.frame.size.width/2 + (CGFloat(ardX)/160) * screenSize.width
        if !disconnected {
            if (ardX - pastXServoVal > 1 || ardX - pastXServoVal < -1) {
                var (sendSuccess, sendErrmsg) = client.send(str:"x/\(ardX)/")
                pastXServoVal = ardX
                //print("xservo: \(ardX)")
            }
        }
        
        var ardY = (1 - (zGravity)) * 70
        if ardY < 0 {
            ardY = 0
        }
        else if ardX > 160 {
            ardX = 160
        }
        ardY = round(100 * ardY) / 100
        //self.accelImg.frame.origin.y = -self.accelImg.frame.size.height/2 + CGFloat(ard)/150 * screenSize.height
        if !self.disconnected {
            if (ardY - self.pastYServoVal > 1 || ardY - self.pastYServoVal < -1) {
                var (sendSuccess, sendErrmsg) = self.client.send(str:"y/\(ardY)/")
                self.pastYServoVal = ardY
                //print("xservo: \(ardX)")
            }
        }
        //self.quaternion = motion!.attitude.quaternion
        //self.tilt = motion!.gravity.y
        
        
    }
    
    func listenVolumeButton(){
        
        if let view = volumeView.subviews.first as? UISlider{
            view.value = 0.0 //---0 t0 1.0---
            
        }
        volumeView.showsVolumeSlider = false
        let audioSession = AVAudioSession.sharedInstance()
        startVolume = 0
        do {
            try audioSession.setActive(true)
        } catch _ {
            
        }
        audioSession.addObserver(self, forKeyPath: "outputVolume",
                                 options: NSKeyValueObservingOptions.New, context: nil)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume"{
            let volume = AVAudioSession.sharedInstance().outputVolume
            print("\(startVolume) \(volume)")
            videoImage.frame.size.width = screenSize.width * (1 + 3 * CGFloat(volume))
            videoImage.frame.size.height = screenSize.width * (3/4) * (1 + 3 * CGFloat(volume))
            videoImage.frame.origin.x = (screenSize.width - videoImage.frame.size.width)/2
            videoImage.frame.origin.y = (screenSize.height - videoImage.frame.size.height)/2
        }
    }
    
    func animateAlert() {
        UIView.animateWithDuration(1, animations: { () -> Void in
            self.alertImg.transform = CGAffineTransformMakeScale(1.5, 1.5)
        }) { (finished: Bool) -> Void in
            UIView.animateWithDuration(1, animations: { () -> Void in
                self.alertImg.transform = CGAffineTransformIdentity
            })}
    }
    
    func vibrate() {
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        vibrationCount++
        if vibrationCount == 2 {
            vibrationCount = 0
            vibrationTimer.invalidate()
        }
    }
    
}
