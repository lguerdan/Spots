//
//  post.swift
//  IOSFinalProject
//
//  Created by Luke Guerdan on 11/28/17.
//  Copyright © 2017 Team 4. All rights reserved.
//

import Foundation
import UIKit

struct Post {
    var name : String
    var photo: UIImageView
    var description : String
    var startTime: Date
    var duration: Int
    var latitude: Double
    var longitude: Double
    var isOwner: Bool
    var numFlags: Int
}
