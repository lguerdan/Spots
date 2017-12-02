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
    @IBOutlet weak var dogDesc: UITextView!
    @IBOutlet weak var dogName: UITextField!
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func resignKeyboard() {
        durationTextField.resignFirstResponder()
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
    
    // Populate post struct with fields for a post
    func createNewDogPost(){
        
        var currDate = Date()
        
//        var post = Post(latitude: latitude, longitude: longitude ,numFlags: 0, startTime: currDate)
    }
    
    @IBAction func submitDogPost(_ sender: Any) {
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


