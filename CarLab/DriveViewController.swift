//
//  DriveViewController.swift
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

let autoStart = true

class DriveViewController: UIViewController, CLLocationManagerDelegate {
    
    let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    
    let deepRed = UIColor(red: 208/255, green: 80/255, blue: 80/255, alpha: 1.0)

    let videoImage: UIImageView = UIImageView()
    var streamingController: MjpegStreamingController!
    //let videoUrl = NSURL(string: "http://10.9.146.228:8080/?action=stream")
    let videoUrl = NSURL(string: "http://192.168.240.1:8080/?action=stream")
    
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
    let blinkImg: UIImageView = UIImageView()
    
    var allowVibration: Bool = true
    var animateTimer: NSTimer = NSTimer()
    var vibrationTimer: NSTimer = NSTimer()
    var blinkTimer: NSTimer = NSTimer()
    var vibrationCount: Int = 0
    var alertCount: Int = 0
    
    var centerLabel: UILabel = UILabel()

    let reverseButton: UIButton = UIButton()

    var inReverse: Bool = false
    
    //******************
    // lifecycle methods
    //******************
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.view.backgroundColor = UIColor.whiteColor()//deepRed
        
        // set up volume rockers
        let volumeView: MPVolumeView = MPVolumeView()
        volumeView.hidden = false
        volumeView.sizeToFit()
        volumeView.frame = CGRectMake(screenSize.width, screenSize.height, 0, 0)
        self.view.addSubview(volumeView)
        
        // Notify when entering and leaving app
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("leavingApp:"), name:UIApplicationDidEnterBackgroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("leavingApp:"), name:UIApplicationWillTerminateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("enterApp:"), name:UIApplicationDidBecomeActiveNotification, object: nil)
        
        // timers to update servos and read from ping
        let servoTimer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: "updateServos", userInfo: nil, repeats: true)
        let readTimer = NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: "readData", userInfo: nil, repeats: true)
        
        // Video feed image
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
        //videoImage.image = UIImage(named: "road")
        
        streamingController = MjpegStreamingController(imageView: videoImage)
        
        // auto start connections on boot up
        if autoStart {
            //client = TCPClient(addr: "10.9.146.228", port: 5678)
            client = TCPClient(addr: "192.168.240.1", port: 5678)
            // connect socket
            var (success, errmsg) = client.connect(timeout: 10)
            print("connect success: \(success)")
            if (success) {
                disconnected = false
                var (sendSuccess, sendErrmsg) = client.send(str:"Start")
            }
            streamingController.play(url: videoUrl!)
        }
        
        streamingController.didStartLoading = { [unowned self] in
            self.loadingIndicator.hidden = false
            self.loadingIndicator.startAnimating()
        }
        streamingController.didFinishLoading = { [unowned self] in
            self.loadingIndicator.stopAnimating()
            self.loadingIndicator.hidden = true
        }
        
        // read accelerometers and gyroscopes
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
        
        // set up compass readings
        lm = CLLocationManager()
        lm.headingOrientation = CLDeviceOrientation.LandscapeLeft
        lm.delegate = self
        lm.startUpdatingHeading()
        readOrientation = 0
        
        // refresh button
        let refreshOrientation = UIButton(type: UIButtonType.System) as UIButton
        refreshOrientation.backgroundColor = UIColor.whiteColor()
        refreshOrientation.titleLabel!.font = UIFont(name: "ChalkboardSE-Bold", size: 14)
        refreshOrientation.frame = CGRectMake(0, 0, screenSize.width * 0.12, screenSize.height * 0.09)
        refreshOrientation.frame.origin.x = (screenSize.width - refreshOrientation.frame.size.width)*0.96
        refreshOrientation.frame.origin.y = (screenSize.height - refreshOrientation.frame.size.height)*0.1
        refreshOrientation.setTitle("Refresh", forState: UIControlState.Normal)
        let lightBlueColor = UIColor(red: 50/255, green: 70/255, blue: 147/255, alpha: 1.0)
        refreshOrientation.setTitleColor(deepRed, forState: UIControlState.Normal)
        refreshOrientation.addTarget(self, action: "refreshAction:", forControlEvents: UIControlEvents.TouchUpInside)
        refreshOrientation.layer.cornerRadius = 10
        self.view.addSubview(refreshOrientation)
        
        // back button
        let backArrow = UIButton(type: UIButtonType.System) as UIButton
        backArrow.frame = CGRectMake(0, 0, screenSize.width * 0.10, screenSize.height * 0.09)
        backArrow.frame.origin.x = (screenSize.width - backArrow.frame.size.width)*0.04
        backArrow.frame.origin.y = (screenSize.height - backArrow.frame.size.height)*0.1
        backArrow.setImage(UIImage(named: "leftarrow.png"), forState: UIControlState.Normal)
        backArrow.addTarget(self, action: "back:", forControlEvents: UIControlEvents.TouchUpInside)
        backArrow.setTitleColor(UIColor.blackColor(), forState: UIControlState.Normal)
        backArrow.tintColor = deepRed
        backArrow.backgroundColor = UIColor.whiteColor()
        backArrow.layer.cornerRadius = 10
        self.view.addSubview(backArrow)
        
        // reverse driving button
        reverseButton.frame = CGRectMake(0, 0, screenSize.width * 0.1, screenSize.width * 0.1)
        reverseButton.frame.origin.x = (screenSize.width - reverseButton.frame.size.width)*0.685
        reverseButton.frame.origin.y = (screenSize.height - reverseButton.frame.size.height)*0.95
        reverseButton.setImage(UIImage(named: "reverse1"), forState: UIControlState.Normal)
        reverseButton.addTarget(self, action: "reverseAction:", forControlEvents: UIControlEvents.TouchUpInside)
        self.view.addSubview(reverseButton)
        
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
        speedSlider.minimumTrackTintColor = deepRed
        speedSlider.maximumTrackTintColor = UIColor.lightGrayColor()
        self.view.addSubview(speedSlider)
        speedLabel.text = "0.0 ft/sec"
        speedLabel.textAlignment = .Center
        speedLabel.font = UIFont(name: "Menlo", size: 18)
        speedLabel.frame = CGRectMake(0, 0, screenSize.width*0.2, screenSize.height * 0.10)
        speedLabel.frame.origin.x = speedSlider.frame.origin.x - speedSlider.frame.size.width*1.4
        speedLabel.frame.origin.y = speedSlider.frame.origin.y + speedSlider.frame.size.height/2 + screenSize.height/3.2
        speedLabel.backgroundColor = UIColor.whiteColor()
        speedLabel.textColor = deepRed
        speedLabel.layer.masksToBounds = true
        speedLabel.layer.cornerRadius = 10
        self.view.addSubview(speedLabel)
        
        // center flag - notifys user of orientation
        centerLabel.frame = CGRectMake(0, 0, screenSize.width*0.14, screenSize.height*0.08)
        centerLabel.frame.origin.x = (screenSize.width - centerLabel.frame.size.width)*0.5
        centerLabel.frame.origin.y = (0 - centerLabel.frame.size.height)*0.1
        centerLabel.text = "center"
        centerLabel.textAlignment = .Center
        centerLabel.font = UIFont(name: "Menlo", size: 20)
        centerLabel.textColor = UIColor.whiteColor()
        centerLabel.backgroundColor = deepRed
        centerLabel.layer.masksToBounds = true
        centerLabel.layer.cornerRadius = 10
        self.view.addSubview(centerLabel)
        
        let imgDiff = screenSize.width/5
        
        listenVolumeButton()
        
        // alert when close to walls
        alertImg.frame = CGRectMake(0, 0, screenSize.width*0.25, screenSize.width * 0.23)
        alertImg.frame.origin.x = (screenSize.width - alertImg.frame.size.width)*0.5
        alertImg.frame.origin.y = (screenSize.height - alertImg.frame.size.height)*0.5
        alertImg.image = UIImage(named: "alert")
        
        blinkImg.frame = CGRectMake(0, 0, screenSize.width, screenSize.height*0.1)
        blinkImg.frame.origin.x = 0
        blinkImg.frame.origin.y = -screenSize.height*0.1
        blinkImg.backgroundColor = UIColor.blackColor()
        self.view.addSubview(blinkImg)
        

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
    
    // click back
    func back(sender:UIButton!) {
        self.navigationController?.popToRootViewControllerAnimated(true)
    }
    
    // refresh orientation to center
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
    
    // connect to arduino
    func startConnection(sender:UIButton!) {
        if disconnected {
            var (success, errmsg) = client.connect(timeout: 10)
            print("connect success: \(success)")
            disconnected = false
            streamingController.play(url: videoUrl!)
        }
    }
    
    // disconnect from arduino
    func stopConnection(sender:UIButton!) {
        var (success, errmsg) = client.send(str:"stop/")
        print("disconnect success: \(success)")
        disconnected = true
        streamingController.stop()
    }
    
    // app terminated: disconnect
    func leavingApp(sender: AnyObject!) {
        print("leaving App")
        var (success, errmsg) = client.send(str:"stop/")
        print("disconnect success: \(success)")
        disconnected = true
        streamingController.stop()
    }
    
    // app opened: connect
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
    
    // adjusting steering slider
    func grabbingSteeringSlider(sender:UISlider!) {
        if (sender.value > 0.51) {
            sender.minimumTrackTintColor = deepRed
            sender.maximumTrackTintColor = UIColor.lightGrayColor()
            steeringImg.image = UIImage(named: "rightturn")
        }
        else if (sender.value < 0.49) {
            sender.minimumTrackTintColor = UIColor.lightGrayColor()
            sender.maximumTrackTintColor = deepRed
            steeringImg.image = UIImage(named: "leftturn")
        }
        
        // send info to arduino
        if !disconnected {
            if (pastSteeringVal - steeringSlider.value > 0.04 || pastSteeringVal - steeringSlider.value < -0.04) {
                let steeringVal = Int(((steeringSlider.value) * 142.8) + 127.5)
                if steeringVal > 255 {
                    var (sendSuccess, sendErrmsg) = client.send(str:"s/254/")
                }
                else {
                    var (sendSuccess, sendErrmsg) = client.send(str:"s/\(steeringVal)/")
                }
                pastSteeringVal =  steeringSlider.value
            }
        }
        
    }
    
    // let go of steering: recenter wheels
    func releaseSteeringSlider(sender:UISlider!) {
        UIView.animateWithDuration(0.4, delay: 0.0, options: .CurveEaseInOut, animations: {
            sender.setValue(0.5, animated: true) },
                                   completion: nil)
        sender.maximumTrackTintColor = UIColor.lightGrayColor()
        sender.minimumTrackTintColor = UIColor.lightGrayColor()
        steeringImg.image = UIImage(named: "straight2")
        // send info to arduino
        if !disconnected {
            var (sendSuccess, sendErrmsg) = client.send(str:"s/198.9/")
            pastSteeringVal =  0.5
        }
    }
    
    // adjusting speed
    func grabbingSpeedSlider(sender:UISlider!) {
        if (sender.value > 0.2) {
            speedLabel.text = String(format: "%.1f ft/sec", 3 + (sender.value * 3))
        }
        else {
            speedLabel.text = String(format: "%.1f ft/sec", 0.0)
        }
        // send info to arduino
        if !disconnected {
            if (pastSpeedVal - speedSlider.value > 0.02 || pastSpeedVal - speedSlider.value < -0.02) {
                var speedVal = Int(((speedSlider.value) * 50) + 1)
                if inReverse {
                    speedVal += 77
                }
                var (sendSuccess, sendErrmsg) = client.send(str:"d/\(speedVal)/")
                pastSpeedVal =  speedSlider.value
            }
        }
    }
    
    // release speed control: stop car
    func releaseSpeedSlider(sender:UISlider!) {
        UIView.animateWithDuration(0.4, delay: 0.0, options: .CurveEaseInOut, animations: {
            sender.setValue(0.0, animated: true) },
                                   completion: nil)
        speedLabel.text = "0.0 ft/sec"
        
        if !disconnected {
            if inReverse {
                var (sendSuccess, sendErrmsg) = client.send(str:"d/78/")
            }
            else {
                var (sendSuccess, sendErrmsg) = client.send(str:"d/1/")
            }
            pastSpeedVal =  0
        }
    }
    
    // read ping information
    func readData() {
        // request read from socket
        var (sendSuccess, sendErrmsg) = client.send(str:"r/0")
        if sendSuccess {
            // read 4 bytes
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
            //alert and vibrate if close to wall
            if allowVibration && value < 4000 {
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
            else if !allowVibration && value > 4150 {
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
    
    // update servo values based on device posiitoning
    func updateServos() {
        var ardX = 77 - (orientationDiff * (154/200))
        if ardX < 0 {
            ardX = 0
        }
        else if ardX > 154 {
            ardX = 154
        }
        ardX = round(100 * ardX) / 100
        // send info to arduino
        self.centerLabel.frame.origin.x = -self.centerLabel.frame.size.width/2 + (CGFloat(ardX)/154) * screenSize.width
        if !disconnected {
            if (ardX - pastXServoVal > 2 || ardX - pastXServoVal < -2) {
                var (sendSuccess, sendErrmsg) = client.send(str:"x/\(ardX)/")
                pastXServoVal = ardX
                print("xServo: \(ardX)")
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
        // send info to arduino
        if !self.disconnected {
            if (ardY - self.pastYServoVal > 2 || ardY - self.pastYServoVal < -2) {
                var (sendSuccess, sendErrmsg) = self.client.send(str:"y/\(ardY)/")
                self.pastYServoVal = ardY
                //print("xservo: \(ardX)")
            }
        }
        //self.quaternion = motion!.attitude.quaternion
        //self.tilt = motion!.gravity.y
        
        
    }
    
    // volume rocker notification
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
    
    // volume rocker notification
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
    
    // alert animation
    func animateAlert() {
        UIView.animateWithDuration(1, animations: { () -> Void in
            self.alertImg.transform = CGAffineTransformMakeScale(1.5, 1.5)
        }) { (finished: Bool) -> Void in
            UIView.animateWithDuration(1, animations: { () -> Void in
                self.alertImg.transform = CGAffineTransformIdentity
            })}
    }
    
    //create vibration
    func vibrate() {
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        vibrationCount++
        if vibrationCount == 2 {
            vibrationCount = 0
            vibrationTimer.invalidate()
        }
    }
    
    // user clicks reverse button: alert the car
    func reverseAction(sender:UIButton!) {
        // put in front drive
        if inReverse {
            alertImg.alpha = 1.0
            reverseButton.setImage(UIImage(named: "reverse1"), forState: UIControlState.Normal)
            inReverse = false
            var (sendSuccess, sendErrmsg) = client.send(str:"z/0/")
            (sendSuccess, sendErrmsg) = client.send(str:"d/1/")
        }
        // put in reverse drive
        else {
            alertImg.alpha = 0.0
            reverseButton.setImage(UIImage(named: "reverse2"), forState: UIControlState.Normal)
            inReverse = true
            var (sendSuccess, sendErrmsg) = client.send(str:"z/160/")
            (sendSuccess, sendErrmsg) = client.send(str:"d/78/")
        }
        blinkImg.alpha = 1.0
        UIView.animateWithDuration(0.4, animations: { () -> Void in
            self.blinkImg.transform = CGAffineTransformMakeScale(24, 24)
        }) { (finished: Bool) -> Void in
            UIView.animateWithDuration(0.4, animations: { () -> Void in
                self.blinkImg.transform = CGAffineTransformIdentity
            })}
        let blinkTimer = NSTimer.scheduledTimerWithTimeInterval(0.8, target: self, selector: "blink", userInfo: nil, repeats: false)
    }
    
    
    func blink() {
        blinkImg.alpha = 0.0
    }
    
}

