//
//  CreatePostViewController.swift
//  IOSFinalProject
//
//  Created by Cameron Wandfluh on 11/16/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import UIKit


class CreatePostViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var latitude: Double? = nil
    var longitude: Double? = nil

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var dogName: UITextField!
    @IBOutlet weak var dogDesc: UITextView!
    @IBOutlet weak var durationTextField: UITextField!
    
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
                
        //Duration picker
        durationPicker.delegate = self
        durationPicker.dataSource = self
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(CreatePostViewController.resignKeyboard))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([flexibleSpace, doneButton], animated: false)
        
        durationTextField.inputView = durationPicker
        durationTextField.inputAccessoryView = toolBar
        
        durationTextField.delegate = self
        durationTextField.tintColor = .clear
        //end of duration picker
        
        //Dog name input field accessory and delegate (incase the hit return instead of done)
        dogName.inputAccessoryView = toolBar
        dogName.delegate = self
        //toolbar
        
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
            print("nil 1")
            return
        }
        if dogDesc == nil || dogName == nil || durationTextField == nil{
            print("nil 2")
            return
        }
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
            guard error == nil else {
                print("User error")
                return
            }
            
            var userName : String
            userName = user?.firstName ?? ""
            userName += user?.lastName ?? ""
            
            let post = Post(name: name, photo: image, description: description,
                            startTime: currDate,  duration: durationInt, latitude: latitude,
                            longitude: longitude, isOwner: false, numFlags: 0, posterName: userName)
            
            print(post)
            // Perform Save
            zone.save(post, completionHandler: { (error) in
                if error != nil{
                    print(error as Any)
                }

            })
        })
    }
    
    @IBAction func cancelDogPost(_ sender: Any) {
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
    func textFieldDidBeginEditing(_ textField: UITextField) {
        durationTextField.text = times.first
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dogName.resignFirstResponder()
        return true
    }
}

extension CreatePostViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        moveTextView(textView, moveDistance: -250, up: true)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        moveTextView(textView, moveDistance: -250, up: false)
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
