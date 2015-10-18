//
//  ViewController.swift
//  TestCanera
//
//  Created by suika069 on 2015/10/12.
//  Copyright © 2015年 suika069. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion

class ViewController: UIViewController {
    
    //画面タッチ時の動作状態を示す値
    enum TapedViewType {
        case Focus
        case Exposure
        case None
    }
    //本体の向きを示す値
    enum BodyRotate {
        case Portrait
        case LandscapeRight
        case LandscapeLeft
        case BackDown
        case Unknown
    }
    
    // セッション.
    var mySession : AVCaptureSession!
    // デバイス.
    var myDevice : AVCaptureDevice!
    // 映像のインプット
    var videoInput: AVCaptureInput!
    // 画像のアウトプット.
    var myImageOutput : AVCaptureStillImageOutput!
    //ナビゲーションバー
    var oNavigationBar: UINavigationBar?
    //ツールバー
    var oToolbar: UIToolbar?
    //フラッシュボタン
    var flashButton: UIButton?
    //各種View
    var viewType: TapedViewType = TapedViewType.None
    var focusView: UIImageView?
    var exposureView: UIImageView?
    //端末の向き
    var BODY_ROTATE: BodyRotate = BodyRotate.Unknown
    //カメラの向き
    var CAMERA_FRONT: Bool = false
    //フラッシュのモード
    var FLASH_MODE: Bool = false
    //
    var adjustingExposure: Bool = false
    // 回転検出用加速度センサー
    let motionManager = CMMotionManager()
    
    // 解放
    deinit {
        AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo).removeObserver(self, forKeyPath: "adjustingExposure")
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //アラート表示
    func popAlartDisplay(title :String, message :String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let defaultAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alertController.addAction(defaultAction)
        self.presentViewController(alertController, animated: true, completion: nil)
        
    }
    
    // Viewの生成
    override func viewDidLoad() {
        super.viewDidLoad()
        //背景を白色にする
        self.view.backgroundColor = UIColor.whiteColor()
        
        //露出のプロパティを監視する
        AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo).addObserver(self, forKeyPath: "adjustingExposure", options: NSKeyValueObservingOptions.New, context: nil)
        
        //バックグラウンドになった時に呼ばれる
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationBecomeActive", name: UIApplicationDidBecomeActiveNotification, object: nil)
        
        //マルチタスクから復帰したときに呼ばれる
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationResignActive", name: UIApplicationWillResignActiveNotification, object: nil)
        
        // セッションの作成.
        mySession = AVCaptureSession()
        // デバイス一覧の取得.
        let devices = AVCaptureDevice.devices()
        
        // バックカメラをmyDeviceに格納.
        for device in devices{
            if(device.position == AVCaptureDevicePosition.Back){
                myDevice = device as! AVCaptureDevice
            }
        }
        // バックカメラからVideoInputを取得.
        do {
            videoInput = try AVCaptureDeviceInput.init(device: myDevice!)
        }catch{
            videoInput = nil
        }
        // セッションに追加.
        mySession.addInput(videoInput)
        // 出力先を生成.
        myImageOutput = AVCaptureStillImageOutput()
        // セッションに追加.
        mySession.addOutput(myImageOutput)
        
        // 画像を表示するレイヤーを生成.
        let myVideoLayer : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer.init(session:mySession)
        //myVideoLayer.frame = self.view.bounds
        //UIViewController.viewの座標取得後加工
        let x:CGFloat = self.view.bounds.origin.x
        let y:CGFloat = self.view.bounds.origin.y
        
        //UIViewController.viewの幅と高さを取得
        let width:CGFloat = self.view.bounds.width;
        let height:CGFloat = self.view.bounds.height
        
        //フレームを生成する
        myVideoLayer.frame = CGRect(x: x, y: y, width: width, height: height)
        myVideoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        // Viewに追加.
        self.view.layer.addSublayer(myVideoLayer)
        
        // セッション開始.
        mySession.startRunning()
        
        //回転か？
        motionManager.accelerometerUpdateInterval = 1
        // 値取得時にしたい処理を作成
        let accelerometerHandler:CMAccelerometerHandler = {
            (data: CMAccelerometerData?, error: NSError?) -> Void in
            // 取得した値をコンソールに表示
            self.bodyRotateStats(Double(Int(data!.acceleration.x * 100.0)) / 100.0)
        }
        /* 加速度センサーを開始する */
        motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.currentQueue()!, withHandler: accelerometerHandler)
        
        //フラッシュ変更ボタン
        flashButton = UIButton.init(type: UIButtonType.Custom)
        flashButton!.frame = CGRectMake(0, 0, 44, 44);
        flashButton!.setImage(UIImage(named: "flash"), forState: UIControlState.Normal)
        flashButton!.addTarget(self, action: "changeFlashMode:", forControlEvents: UIControlEvents.TouchUpInside)
        let changeFlashButton = UIBarButtonItem(customView: flashButton!)
        
        //カメラ向き変更ボタン
        let changeCameraButton = UIBarButtonItem(image: UIImage(named: "change_camera"), style: UIBarButtonItemStyle.Plain, target: self, action: "changeCamera:")
        
        //ナビゲーションバー
        oNavigationBar = UINavigationBar(frame: CGRectMake(0, 0, self.view.frame.size.width, 44+20))
        oNavigationBar!.barStyle = UIBarStyle.Default
        //oNavigationBar!.tintColor = UIColor.whiteColor()
        oNavigationBar!.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(oNavigationBar!)
        
        let naviItem:UINavigationItem = UINavigationItem(title: "Test Camera")
        naviItem.leftBarButtonItems = [changeFlashButton]
        naviItem.rightBarButtonItems = [changeCameraButton];
        oNavigationBar!.setItems([naviItem], animated: false)
        //スペース
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        
        //撮影ボタン
        let takePhotoButton = UIBarButtonItem.init(image: UIImage(named: "shutter"), style: UIBarButtonItemStyle.Plain, target: self, action: "onClickMyButton:")
        
        //ツールバーを生成
        oToolbar = UIToolbar(frame: CGRectMake(0, self.view.frame.size.height-50, self.view.frame.size.width, 55))
        oToolbar!.barStyle = UIBarStyle.BlackTranslucent
        oToolbar!.tintColor = UIColor.whiteColor()
        oToolbar!.backgroundColor = UIColor.blackColor()
        oToolbar!.items = [spacer,takePhotoButton,spacer]
        self.view.addSubview(oToolbar!)
        
        //フォーカスビュー
        focusView = UIImageView(frame: CGRectMake(0, 0, 60, 60))
        focusView!.userInteractionEnabled = true;
        focusView!.center = self.view!.center;
        focusView!.image = UIImage(named: "focus_circle")
        self.view.addSubview(focusView!)
        
        //露出
        exposureView = UIImageView(frame: focusView!.frame)
        exposureView!.userInteractionEnabled = true;
        exposureView!.image = UIImage(named: "exposure_circle")
        self.view.addSubview(exposureView!)
        
    }
    
    // ボタンイベント.
    // フラッシュモードの変更
    func changeFlashMode(sender: AnyObject?) {
        FLASH_MODE = !FLASH_MODE;
        if(FLASH_MODE){
            flashButton?.setImage(UIImage(named: "flash_on"), forState: UIControlState.Normal)
            if myDevice.hasFlash {
                do {
                    try myDevice.lockForConfiguration()
                    myDevice.flashMode = AVCaptureFlashMode.On
                    myDevice.unlockForConfiguration()
                }catch{
                    //
                }
            }
        }else{
            flashButton?.setImage(UIImage(named: "flash"), forState: UIControlState.Normal)
            if myDevice.hasFlash {
                do {
                    try myDevice.lockForConfiguration()
                    myDevice.flashMode = AVCaptureFlashMode.Off
                    myDevice.unlockForConfiguration()
                }catch{
                    //
                }
            }
        }
    }
    
    // カメラ向き変更ボタン
    func changeCamera(sender : AnyObject) {
        //今と反対の向きを判定
        CAMERA_FRONT = !CAMERA_FRONT;
        var position: AVCaptureDevicePosition! = AVCaptureDevicePosition.Back
        if(CAMERA_FRONT){
            position = AVCaptureDevicePosition.Front;
        }
        //セッションからvideoInputの取り消し
        mySession?.removeInput(videoInput);
        
        // デバイス一覧の取得.
        let devices = AVCaptureDevice.devices()
        
        // バックカメラをmyDeviceに格納.
        for device in devices{
            if(device.position == position){
                myDevice = device as! AVCaptureDevice
                
                if(CAMERA_FRONT){
                    //フロントカメラになった
                    if(FLASH_MODE){
                        //フラッシュをOFFにする
                        self.changeFlashMode(nil)
                    }
                    flashButton!.enabled = false;
                }else{
                    flashButton!.enabled = true;
                }
            }
        }
        // バックカメラからVideoInputを取得.
        do {
            videoInput = try AVCaptureDeviceInput(device: myDevice!)
        }catch{
            videoInput = nil
        }
        
        // セッションに追加.
        mySession.addInput(videoInput)
        
    }
    
    // 撮影ボタン
    func onClickMyButton(sender: UIButton){
        // ビデオ出力に接続.
        let myVideoConnection = myImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        
        //回転を判定
        if self.isRotate() == BodyRotate.LandscapeLeft {
            //self.popAlartDisplay("回転", message: "現在端末は左横向きです")
            myVideoConnection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
        } else if self.isRotate() == BodyRotate.LandscapeRight {
            //self.popAlartDisplay("回転", message: "現在端末は右横向きです")
            myVideoConnection.videoOrientation = AVCaptureVideoOrientation.LandscapeLeft
        } else {
            myVideoConnection.videoOrientation = AVCaptureVideoOrientation.Portrait
        }
        // 接続から画像を取得.
        self.myImageOutput.captureStillImageAsynchronouslyFromConnection(myVideoConnection, completionHandler: { (imageDataBuffer, error) -> Void in
            
            // 取得したImageのDataBufferをJpegに変換.
            let myImageData : NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataBuffer)
            // JpegからUIIMageを作成.
            let myImage : UIImage = UIImage(data: myImageData)!
            //イメージを保存
            UIImageWriteToSavedPhotosAlbum(myImage, self, nil, nil)
        })
        
    }
    
    // アプリがフォアグラウンドで有効な状態になった時
    func applicationBecomeActive() {
        //カメラの起動
        if(mySession != nil){
            mySession!.startRunning()
        }
    }
    
    // アプリがバックグラウンドで無効な状態になった時
    func applicationResignActive() {
        //カメラの停止
        if(mySession != nil){
            mySession!.stopRunning()
        }
    }
    
    // Viewが触られた時
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent!) {
        //触られたViewを判定する
        let touch: UITouch = touches.first as UITouch!
        if(touch.view == focusView){
            viewType = TapedViewType.Focus;
        }else if(touch.view == exposureView){
            viewType = TapedViewType.Exposure;
        }else{
            viewType = TapedViewType.None;
        }
    }
    
    // Viewが触られている時
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent!) {
        if(viewType != TapedViewType.None){
            let touch: UITouch = touches.first as UITouch!
            let location: CGPoint = touch.locationInView(self.view)
            if(location.x > focusView!.frame.size.width/2){
                if(location.x < self.view.frame.size.width-focusView!.frame.size.width/2){
                    if(location.y > focusView!.frame.size.height/2+oNavigationBar!.frame.origin.y+oNavigationBar!.frame.size.height){
                        if(location.y < self.view.frame.size.height-oToolbar!.frame.size.height-focusView!.frame.size.height/2){
                            //フォーカスか露出をカメラ映像内で移動させる
                            if(viewType == TapedViewType.Focus){
                                focusView?.center = location;
                            }else if(viewType == TapedViewType.Exposure){
                                exposureView?.center = location;
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Viewを触るのをキャンセルされた
    override func touchesCancelled(touches: Set<UITouch>!, withEvent event: UIEvent!) {
        if(viewType != TapedViewType.None){
            //フォーカスか露出の調整中にキャンセルされた時、正常終了のメソッドも呼ぶ
            self.touchesEnded(touches, withEvent: event)
        }
    }
    
    // Viewを触り終わった時
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent!) {
        if(viewType != TapedViewType.None){
            //対象座標を作成
            let touch: UITouch = touches.first as UITouch!
            let location: CGPoint = touch.locationInView(self.view)
            let viewSize: CGSize = self.view.bounds.size;
            let pointOfInterest: CGPoint = CGPointMake(location.y / viewSize.height, 1.0 - location.x / viewSize.width);
            
            if(viewType == TapedViewType.Focus){
                //フォーカスを合わせる
                let camera: AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
                if(camera.isFocusModeSupported(AVCaptureFocusMode.AutoFocus)) {
                    do {
                        try camera.lockForConfiguration()
                        camera.focusPointOfInterest = pointOfInterest;
                        camera.focusMode = AVCaptureFocusMode.AutoFocus;
                        camera.unlockForConfiguration()
                    } catch {
                        //
                    }
                }
            }else if(viewType == TapedViewType.Exposure){
                //露出を合わせる
                let camera: AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
                if (camera.isExposureModeSupported(AVCaptureExposureMode.ContinuousAutoExposure)){
                    adjustingExposure = true
                    do {
                        try camera.lockForConfiguration()
                        camera.exposurePointOfInterest = pointOfInterest;
                        camera.exposureMode = AVCaptureExposureMode.ContinuousAutoExposure;
                        camera.unlockForConfiguration()
                    } catch {
                        //
                    }
                }
            }
            viewType = TapedViewType.None;
        }
    }
    
    // 露出のプロパティが変更された
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        //露出が調整中じゃない時は処理を返す
        if (!self.adjustingExposure) {
            return
        }
        //露出の情報
        if keyPath == "adjustingExposure" {
            let isNew = change?[NSKeyValueChangeNewKey]
            if (isNew != nil) {
                //露出が決定した
                self.adjustingExposure = false
                //露出を固定する
                let camera: AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
                do {
                    try camera.lockForConfiguration()
                    camera.exposureMode = AVCaptureExposureMode.Locked
                    camera.unlockForConfiguration()
                } catch {
                    //
                }
            }
        }
    }
    
    // 加速度センサーの値から、端末の方向を特定する
    func bodyRotateStats(radiation: Double) {
        // 端末の向きを取得
        if radiation >= 0.90 {
            BODY_ROTATE = BodyRotate.LandscapeRight
        } else if radiation <= -0.90 {
            BODY_ROTATE = BodyRotate.LandscapeLeft
        } else if radiation < 0.90 {
            BODY_ROTATE = BodyRotate.Portrait
        } else if radiation > -0.90 {
            BODY_ROTATE = BodyRotate.BackDown
        } else {
            BODY_ROTATE = BodyRotate.Unknown
        }
    }
    
    //端末横向き状態の取得
    func isRotate() -> BodyRotate {
        return BODY_ROTATE
    }
    
}