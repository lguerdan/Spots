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
    
    let dogPost = DogPost(title: "Spot", desc: "Our mascot is out and about!", coordinate: CLLocationCoordinate2D(latitude: 38.946547, longitude: -92.328597), duration: 15, photo: UIImage(named: "Dog")!, name: "TestTest")
    
    
    let zone = Zone.defaultPublicDatabase()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // retrieving records
        let zone = Zone.defaultPublicDatabase()
        zone.retrieveObjects(completionHandler: { (posts: [Post]) in
            for post in posts{
                print(post.name)
            }
        })
        dogName.text = dogPost.title
        
        
        // Do any additional setup after loading the view.
        setImageIcons()
        //back button color
        self.navigationController?.navigationBar.tintColor = UIColor.white
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
