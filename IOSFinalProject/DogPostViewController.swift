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
    @IBOutlet weak var dogName: UITextField!
    @IBOutlet weak var ownerName: UITextField!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var dogDesc: UITextView!
    @IBOutlet weak var bottomBar: UIToolbar!

    var dogPost: DogPost? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        initDogPostUI()
        setImageIcons()
        
        self.navigationController?.navigationBar.tintColor = UIColor.white
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initDogPostUI(){
        if let dogPost = dogPost {
            dogImage.image = dogPost.photo
            dogName.text = dogPost.title
            dogDesc.text = dogPost.desc
            print(dogPost.description)
            ownerName.text = dogPost.posterName.camelCaseToWords()
        
            print(dogPost.duration)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            formatter.locale = .current
            let strInCurrLocale = formatter.string(from: dogPost.startTime)
            let dateInCurrLocale = formatter.date(from: strInCurrLocale)
            
            
            var endTime = dogPost.startTime.addingTimeInterval(TimeInterval(dogPost.duration * 60))
            var currTime = Date()
            var timeDiff = endTime.timeIntervalSince(currTime)
            print("Duration: \(Double(dogPost.duration))")
            print("Start time:  \(dogPost.startTime)")
            print("End time: \(endTime)")
            print("Time diff: \(timeDiff)")
            print(timeDiff)
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
        flagButton.addTarget(self, action: #selector(segueToPostView), for: .touchUpInside)
        
        let spacing = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        self.bottomBar.setItems([spacing, postBarButton, spacing, flagBarButton], animated: false)
    }

    @objc func segueToPostView() {
        self.navigationController?.popViewController(animated: false)
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
