//
//  post.swift
//  IOSFinalProject
//
//  Created by Luke Guerdan on 11/28/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import Foundation
import UIKit
import MapKit

struct Post : CloudKitCodable,NSObject, MKAnnotation{
    let recordType = "Post"
    var cloudInformation: CloudKitInformation?
    var name : String
    var photo: CodableImage?
    var description : String
    var startTime: Date
    var duration: Int
    var latitude: Double
    var longitude: Double
    var isOwner: Bool
    var numFlags: Int
    var posterName: String
    
    init(name: String, photo: UIImage?, description: String, startTime: Date,
         duration: Int, latitude: Double, longitude: Double, isOwner: Bool, numFlags: Int, posterName: String) {
        
        self.name = name
        self.description = description
        self.startTime = startTime
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.isOwner = isOwner
        self.numFlags = numFlags
        self.posterName = posterName
        
        if let photo = photo {
            self.photo = CodableImage(image: photo)
        } else {
            self.photo = nil
        }
        var subtitle: String? {
            return description
        }
    }
}
