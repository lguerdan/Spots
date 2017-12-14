//
//  CreatePostViewController.swift
//  IOSFinalProject
//
//  Created by Cameron Wandfluh on 11/16/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import UIKit
import MapKit

protocol CreatePostViewControllerDelegate {
    func finishPassing(post: DogPost)
}

class CreatePostViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var delegate : CreatePostViewControllerDelegate?
    var latitude: Double? = nil
    var longitude: Double? = nil

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var dogName: UITextField!
    @IBOutlet weak var dogDesc: UITextView!
    @IBOutlet weak var durationTextField: UITextField!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var postButton: UIBarButtonItem!
    @IBOutlet weak var textViewDesc: UITextView!
    @IBOutlet weak var seperator: UIBarButtonItem!
    
    
    //Duration picker
    var times: [String] = ["5 minutes", "10 mintues", "15 minutes", "30 minutes", "45 minutes", "60 minutes"]
    
    let durationPicker = UIPickerView()
    let toolBar: UIToolbar = {
        let bar = UIToolbar()
        bar.barStyle = .default
        bar.isTranslucent = true
        bar.sizeToFit()
        
        bar.isUserInteractionEnabled = true
        
        return bar
    }()
    
    var hasSubmittedImage: Bool = false
    
    //Image picker
    let picker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGestureRecognizer)
        picker.delegate = self
        
        // change of font and font color of navigation controller
        self.navigationController?.navigationBar.titleTextAttributes = [ NSAttributedStringKey.font: UIFont(name: "Gujarati Sangam MN", size: 20)!, NSAttributedStringKey.foregroundColor: UIColor.white]
        
        //back button color
        self.navigationController?.navigationBar.tintColor = UIColor.white
        
        //toolbar button colors
        self.cancelButton.tintColor = UIColor.white
        self.postButton.tintColor = UIColor.white
    
        
        //position adjustments of toolbar
        self.cancelButton.setTitlePositionAdjustment(UIOffset(horizontal: 10, vertical: 0), for: UIBarMetrics.default)
        seperator.isEnabled = false
        seperator.setTitleTextAttributes([NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: UIFont(name: "Gujarati Sangam MN", size:18) as Any], for: UIControlState.disabled)
        
        //toolbar font
        toolbar.barTintColor = UIColor(rgb: 0xE77C1E)
        
        textViewDesc.delegate = self
        textViewDesc.text = "Tell us about your dog!"
        textViewDesc.textColor = UIColor.lightGray
        
        
        //Max character length
        dogName.delegate = self
        dogDesc.delegate = self
                
        //Duration picker
        durationPicker.delegate = self
        durationPicker.dataSource = self
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(CreatePostViewController.resignKeyboard))
        doneButton.tintColor = UIColor.black
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([flexibleSpace, doneButton], animated: false)
        
        durationTextField.inputView = durationPicker
        durationTextField.inputAccessoryView = toolBar
        
        durationTextField.delegate = self
        durationTextField.tintColor = .clear
        //end of duration picker
     
        //circular UIimage(kind of)
        imageView.layer.cornerRadius = imageView.frame.size.width/2
        imageView.layer.cornerRadius = imageView.frame.size.height/2
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor(rgb: 0xE77C1E).cgColor
        
        
        //Dog description accessory
        dogDesc.inputAccessoryView = toolBar
        dogDesc.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func resignKeyboard() {
        durationTextField.resignFirstResponder()
        dogDesc.resignFirstResponder()
        dogName.resignFirstResponder()
    }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        //let tappedImage = tapGestureRecognizer.view as! UIImageView
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.delegate = self
            picker.sourceType = .camera;
            picker.allowsEditing = false
            self.present(picker, animated: true, completion: nil)
        } else {
            print("Camera not found!")
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage //2
        imageView.contentMode = .scaleAspectFit //3
        imageView.image = chosenImage //4
        hasSubmittedImage = true
        dismiss(animated: true, completion: nil) //5
    }
    
    //What to do if the image picker cancels.
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func DurationButtonPress(_ sender: Any) {
        //Stuff
    }

    
    @IBAction func submitDogPost(_ sender: Any) {
        if self.latitude == nil || self.longitude == nil{
            let alert = UIAlertController(title: "Error Creating Post", message: "This is an alert.", preferredStyle: .alert)
            alert.message = "You have not allowed us to collect your location. Please enable this and try again."
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        if dogDesc == nil || dogName == nil || durationTextField == nil{
            return
        }
        
        if self.dogName.text!.isEmpty || self.dogDesc.text!.isEmpty || self.durationTextField.text!.isEmpty || hasSubmittedImage == false {
            let alert = UIAlertController(title: "Error Creating Post", message: "This is an alert.", preferredStyle: .alert)
            
            if(self.dogName.text!.isEmpty){
                alert.message = "Please provide a dog name."
            }
            
            if(self.dogDesc.text!.isEmpty){
                alert.message = "Please provide a description."
            }
            
            if(self.durationTextField.text!.isEmpty){
                alert.message = "Please provide a post duration."
            }
            
            if(hasSubmittedImage == false){
                alert.message = "Please provide an image."
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
            self.present(alert, animated: true, completion: nil)
        }else{

            let name = self.dogName.text!
            let description = self.dogDesc.text!
            let image = self.imageView.image
            let latitude = self.latitude!
            let longitude =  self.longitude!
            let durationText = self.durationTextField.text!
            print(durationText.components(separatedBy: " ")[1])
            let durationInt = Int(durationText.components(separatedBy: " ")[1])!
            let currDate = Date()
            
            // Retrieve User Information
            let zone = Zone.defaultPublicDatabase()
            zone.userInformation(completionHandler: { (user, error) in
                if error != nil {
                    let alert = UIAlertController(title: "Error Creating Post", message: "This is an alert.", preferredStyle: .alert)
                    alert.message = "You must be signed in to iCloud to create a post. Please sign in through app settings and try again."
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .`default`, handler: { _ in
                        NSLog("The \"OK\" alert occured.")
                    }))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                else{
                    var userName : String
                    userName = user?.firstName ?? ""
                    userName += user?.lastName ?? ""
                    let post = Post(name: name, photo: image, description: description,
                                    startTime: currDate,  duration: durationInt, latitude: latitude, longitude: longitude, isOwner: false, numFlags: 0, posterName: userName)
                    
                    // Perform Save
                    zone.save(post, completionHandler: { (error) in
                        if error != nil{
                            print(error as Any)
                        }
                    })
                    let turnedImage = UIImage(cgImage: (image?.cgImage)!, scale: (image?.scale)!, orientation: UIImageOrientation.up)
                    
                    let dogPost = DogPost(title: name, desc: description, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), duration: durationInt, photo: turnedImage, name: userName, posterName: userName, startTime: currDate)
                    self.delegate?.finishPassing(post: dogPost)
                }
            })
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func cancelDogPost(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func maskRoundedImage(image: UIImage, radius: CGFloat) -> UIImage {
        let imageView: UIImageView = UIImageView(image: image)
        let layer = imageView.layer
        layer.masksToBounds = true
        layer.cornerRadius = radius
        layer.borderWidth = 2
        layer.borderColor = UIColor(rgb: 0xE77C1E).cgColor
        UIGraphicsBeginImageContext(imageView.bounds.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return roundedImage!
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        navigationItem.backBarButtonItem?.tintColor = UIColor.white
        
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}


extension CreatePostViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 12
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dogName.resignFirstResponder()
        return true
    }
}

extension CreatePostViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        moveTextView(textView, moveDistance: -250, up: true)
        if textViewDesc.textColor == UIColor.lightGray {
            textViewDesc.text = nil
            textViewDesc.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        moveTextView(textView, moveDistance: -250, up: false)
        if textViewDesc.text.isEmpty {
            textViewDesc.text = "Tell us about your dog!"
            textViewDesc.textColor = UIColor.lightGray
        }
    }
    
    func moveTextView(_ textView: UITextView, moveDistance: Int, up: Bool) {
        let moveDuration = 0.3
        let movement: CGFloat = CGFloat(up ? moveDistance : -moveDistance)
        
        UIView.beginAnimations("animateTextField", context: nil)
        UIView.setAnimationBeginsFromCurrentState(true)
        UIView.setAnimationDuration(moveDuration)
        self.view.frame = self.view.frame.offsetBy(dx: 0, dy: movement)
        UIView.commitAnimations()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let maxtext: Int = 150
        //If the text is larger than the maxtext, the return is false
        return textView.text.count + (text.count - range.length) <= maxtext
    }
}

extension CreatePostViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        durationTextField.text = "Duration \(times[row])"
    }
}

extension CreatePostViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return times.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return times[row]
    }
}




