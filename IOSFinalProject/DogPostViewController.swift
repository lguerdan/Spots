//
//  DogPostViewController.swift
//  IOSFinalProject
//
//  Created by Jeremy Gonzalez on 12/5/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import UIKit
import CoreLocation

class DogPostViewController: UIViewController {

    @IBOutlet weak var dogImage: UIImageView!
    @IBOutlet weak var dogName: UILabel!
    @IBOutlet weak var ownerName: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var dogDesc: UITextView!
    @IBOutlet weak var bottomBar: UIToolbar!
    @IBOutlet weak var imageView: UIImageView!

    var dogPost: DogPost? = nil
    var timeRemainingSeconds: Int = 0
    var countDownTimer: Timer? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        initDogPostUI()
        setImageIcons()
        
        // change of font and font color of navigation controller
        self.navigationController?.navigationBar.titleTextAttributes = [ NSAttributedStringKey.font: UIFont(name: "Gujarati Sangam MN", size: 20)!, NSAttributedStringKey.foregroundColor: UIColor.white]
        
        //circular UIimage(kind of)
        imageView.layer.cornerRadius = imageView.frame.size.width/2
        imageView.layer.cornerRadius = imageView.frame.size.height/2
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor(rgb: 0xE77C1E).cgColor
        
        // Do any additional setup after loading the view.
        setImageIcons()
        
        //back button color
        self.navigationController?.navigationBar.tintColor = UIColor.white
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func initDogPostUI(){
        if let dogPost = dogPost {
            let newImage = UIImage(cgImage: (dogPost.photo.cgImage!), scale: (dogPost.photo.scale), orientation: UIImageOrientation.right)
            dogImage.image = newImage
            dogName.text = dogPost.title
            dogDesc.text = dogPost.desc
            ownerName.text = dogPost.posterName.camelCaseToWords()
        
            let endTime = dogPost.startTime.addingTimeInterval(TimeInterval(dogPost.duration * 60))
            let currTime = Date()
            timeRemainingSeconds = Int(endTime.timeIntervalSince(currTime))
            
            Timer.scheduledTimer(timeInterval: 1,
                                 target: self,
                                 selector: #selector(self.updateTimer),
                                 userInfo: nil,
                                 repeats: true)
        }
    }
    
    @objc func updateTimer(){
        if(timeRemainingSeconds > 0){
            let seconds = timeRemainingSeconds % 60
            let minutes = (timeRemainingSeconds / 60) % 60
            if seconds < 10{
                duration.text = "\(minutes) : 0\(seconds) remaining"
            }
            else{
               duration.text = "\(minutes) : \(seconds) remaining"
            }
            timeRemainingSeconds -= 1
        }
    }
    
    func setImageIcons() {
        //E77C1E
        let postButton: UIButton = UIButton(type: UIButtonType.custom)
        postButton.frame.size = CGSize(width: 30, height: 30)
        //set frame
        let postSize = postButton.frame.size
        let postImage = UIImage(named: "Plus")?.resizedImageWithinSquare(rectSize: postSize)
        postButton.setImage(postImage, for: .normal)
        let postBarButton = UIBarButtonItem(customView: postButton)
        //assign button to bottombar
        //Need to add segue to the createpost
        postButton.addTarget(self, action: #selector(segueToPostView), for: .touchUpInside)
        
        let flagButton: UIButton = UIButton(type: UIButtonType.custom)
        flagButton.frame.size = CGSize(width: 30, height: 30)
        //set frame
        let flagSize = flagButton.frame.size
        let flagImage = UIImage(named: "Flag")?.resizedImageWithinSquare(rectSize: flagSize)
        flagButton.setImage(flagImage, for: .normal)
        let flagBarButton = UIBarButtonItem(customView: flagButton)
        //assign button to bottombar
        //Need to add segue to the createpost
        flagButton.addTarget(self, action: #selector(flagPost), for: .touchUpInside)
        
        let spacing = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        self.bottomBar.setItems([spacing, postBarButton, spacing, flagBarButton], animated: false)
    }

    @objc func segueToPostView() {
        //self.navigationController?.popViewController(animated: false)
        performSegue(withIdentifier: "ShowCreatePost", sender: nil)
    }
    
    @objc func flagPost() {
        let alert = UIAlertController(title: "Is this post inappropriate?", message: "Would you like to flag this post?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: {
                (alertAction) -> Void in
            }))
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive, handler: {
                (alertAction) -> Void in
                self.navigationController?.popViewController(animated: true)
            }))
        self.present(alert, animated: true, completion: nil)

    }
    
}

extension String {
    
    func camelCaseToWords() -> String {
        
        return unicodeScalars.reduce("") {
            
            if CharacterSet.uppercaseLetters.contains($1) == true {
                
                return ($0 + " " + String($1))
            }
            else {
                
                return $0 + String($1)
            }
        }
    }
}
