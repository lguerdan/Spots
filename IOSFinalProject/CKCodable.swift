
import UIKit
import CoreLocation
import CloudKit

//===----------------------------------------------------------------------===//
// Shared Key Types
//===----------------------------------------------------------------------===//

fileprivate struct _CloudkitKey : CodingKey {
    public var stringValue: String
    public var intValue: Int?
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    fileprivate init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
    
    fileprivate static let `super` = _CloudkitKey(stringValue: "super")!
}

fileprivate class _CKInternalRecord {
    var record: CKRecord
    var attributes: [String: NSObject]
    fileprivate var references: [_CKInternalReference]
    private(set) var children: [String: [_CKInternalRecord]] = [:]
    
    var recordID: CKRecordID {
        return self.record.recordID
    }
    
    var recordType: String {
        return self.record.recordType
    }
    
    init(record: CKRecord) {
        self.record = record
        self.attributes = [:]
        self.references = []
        
        for key in record.allKeys() {
            if let recordValue = record.object(forKey: key) {
                if let reference = recordValue as? CKReference {
                    references.append(_CKInternalReference(childKey: key, reference: reference))
                } else {
                    attributes[key] = (recordValue as! NSObject)
                }
            } else {
                attributes[key] = NSNull()
            }
        }
    }
    
    func toDictionary() -> [String: Any] {
        var attributes: [String: Any] = self.attributes
        
        attributes["cloudInformation"] = self.recordID.recordName
        
        for (key, childen) in self.children where !childen.isEmpty {
            if childen.count == 1 {
                attributes[key] = childen.first!.toDictionary()
            } else {
                attributes[key] = childen.map({ $0.toDictionary() })
            }
        }
        
        return attributes
    }
    
    static func establishRelationships(_ records: [_CKInternalRecord]) -> [_CKInternalRecord] {
        var records: [CKRecordID: _CKInternalRecord] = records.reduce(into: [:], { $0[$1.recordID] = $1 })
        var processedRecords: [_CKInternalRecord] = []
        
        for (_, record) in records {
            if record.references.isEmpty {
                processedRecords.append(record)
            } else {
                for reference in record.references {
                    if let parentRecord = records[reference.parentID], parentRecord.recordType == reference.parentType {
                        parentRecord.children[reference.key, default: []] += [record]
                        reference.established = true
                    }
                }
            }
        }
        
        for (_, record) in records where !processedRecords.contains(where: { $0.recordID == record.recordID }) {
            if record.references.isEmpty {
                processedRecords.append(record)
            } else if !record.references.reduce(false, { $0 || $1.established }) {
                processedRecords.append(record)
            }
        }
        
        return processedRecords
    }
}

fileprivate class _CKInternalReference {
    var parentType: String
    var key: String
    var reference: CKReference
    var established: Bool = false
    
    var parentID: CKRecordID {
        return reference.recordID
    }
    
    init(childKey: String, reference: CKReference) {
        self.reference = reference
        
        let seperatedKeys = childKey.components(separatedBy: "_")
        self.parentType = seperatedKeys.first ?? ""
        self.key = Array(seperatedKeys.dropFirst()).joined(separator: "_")
    }
}

fileprivate struct CloudKitSerialization {
    static func records(fromObject object: NSObject, withType type: String, withZoneID zoneID: CKRecordZoneID? = nil, retrieveExistingRecord existingRecord: ((NSDictionary) -> CKRecord?)? = nil) -> [CKRecord] {
        if let array = object as? NSArray {
            let (_, records, childrenRecords) = CloudKitSerialization._records(fromArray: array, withType: type, withZoneID: zoneID, retrieve: existingRecord)
            return records + childrenRecords
        } else if let dict = object as? NSDictionary {
            let (records, childrenRecords) = CloudKitSerialization._records(fromDictionary: dict, withType: type, withZoneID: zoneID, retrieve: existingRecord)
            return records + childrenRecords
        } else {
            return []
        }
    }
    
    static func object(from records: [CKRecord], retrieveMissingRecords: ((String, String, [CKRecordID], (([CKRecord]) -> Void) ) -> Void)? = nil) -> NSObject? {
        guard !records.isEmpty else { return nil }
        
        let internalRecords = records.map({ _CKInternalRecord(record: $0) })
        let attachedRecords = _CKInternalRecord.establishRelationships(internalRecords)
        
        if attachedRecords.count > 1 {
            return attachedRecords.map({ $0.toDictionary() }) as NSObject
        } else {
            return attachedRecords.first!.toDictionary() as NSObject
        }
    }
}

fileprivate extension CloudKitSerialization {
    fileprivate static func _records(fromArray array: NSArray, withType type: String, withZoneID zoneID: CKRecordZoneID?, retrieve existingRecord: ((NSDictionary) -> CKRecord?)?) -> (elements: NSArray, records: [CKRecord], subRecords: [CKRecord]) {
        var elements: [CKRecordValue] = []
        var records: [CKRecord] = []
        var subRecords: [CKRecord] = []
        
        for value in array {
            if value is NSNumber ||
                value is NSString ||
                value is NSDate ||
                value is CLLocation ||
                value is CKAsset ||
                value is CKReference {
                elements.append((value as! CKRecordValue))
            } else if let value = value as? NSArray {
                let (_, childrenRecords, grandchildrenRecords) = CloudKitSerialization._records(fromArray: value, withType: type, withZoneID: zoneID, retrieve: existingRecord)
                
                records += childrenRecords
                subRecords += grandchildrenRecords
            } else if let value = value as? NSDictionary {
                let (childrenRecords, grandchildrenRecords) = CloudKitSerialization._records(fromDictionary: value, withType: type, withZoneID: zoneID, retrieve: existingRecord)
                
                records += childrenRecords
                subRecords += grandchildrenRecords
            }
        }
        
        return (elements as NSArray, records, subRecords)
    }
    
    fileprivate static func _records(fromDictionary dict: NSDictionary, withType type: String, withZoneID zoneID: CKRecordZoneID?, retrieve existingRecord: ((NSDictionary) -> CKRecord?)?) -> (records: [CKRecord], subRecords: [CKRecord]) {
        let record: CKRecord
        let dependencyRecordTypesKey = "dependencyRecordTypesKey"
        let recordTypeKey = "recordType"
        let recordType = dict.object(forKey: recordTypeKey) as? String ?? type
        
        if let existingRecord = existingRecord?(dict) {
            record = existingRecord
        }else if let zoneID = zoneID {
            record = CKRecord(recordType: recordType, zoneID: zoneID)
        } else {
            record = CKRecord(recordType: recordType)
        }
        
        let attributes: [(String, Any)] = dict.flatMap({
            guard let key = $0 as? String, key != recordTypeKey else { return nil }
            
            return (key, $1)
        })
        
        var subRecords: [CKRecord] = []
        
        var dependencyRecordTypes = Set(((record.object(forKey: dependencyRecordTypesKey) as? NSArray) as? [String]) ?? [])
        
        for (key, value) in attributes {
            if value is NSNumber ||
                value is NSString ||
                value is NSDate ||
                value is CLLocation ||
                value is CKAsset ||
                value is CKReference {
                record.setObject((value as! CKRecordValue), forKey: key)
            } else if let value = value as? NSArray {
                let (elements, childrenRecords, grandchildrenRecords) = CloudKitSerialization._records(fromArray: value, withType: key, withZoneID: zoneID, retrieve: existingRecord)
                
                if elements.count > 0 {
                    record.setObject(elements, forKey: key)
                }
                
                for childRecord in childrenRecords {
                    dependencyRecordTypes.insert("\(childRecord.recordType)_\(key)")
                    childRecord.setObject(CKReference(record: record, action: .deleteSelf), forKey: "\(record.recordType)_\(key)")
                }
                
                subRecords += childrenRecords
                subRecords += grandchildrenRecords
            } else if let value = value as? NSDictionary {
                let (childrenRecords, grandchildrenRecords) = CloudKitSerialization._records(fromDictionary: value, withType: key, withZoneID: zoneID, retrieve: existingRecord)
                
                for childRecord in childrenRecords {
                    dependencyRecordTypes.insert("\(key)_\(childRecord.recordType)")
                    childRecord.setObject(CKReference(record: record, action: .deleteSelf), forKey: "\(record.recordType)_\(key)")
                }
                
                subRecords += childrenRecords
                subRecords += grandchildrenRecords
            }
        }
        
        if !dependencyRecordTypes.isEmpty {
            record.setObject(Array(dependencyRecordTypes) as CKRecordValue, forKey: dependencyRecordTypesKey)
        }
        
        return ([record], subRecords)
    }
}

public struct CodableObject<T: NSCoder>: Codable {
    public let object: T
    
    public init(object: T) { self.object = object }
    
    public init(from decoder: Decoder) throws {
        let data = try decoder.singleValueContainer().decode(Data.self)
        guard let value = NSKeyedUnarchiver.unarchiveObject(with: data) as? T else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize CKLocation from invalid data value \(data)"))
        }
        
        self.object = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(NSKeyedArchiver.archivedData(withRootObject: object))
    }
}

public struct CodableLocation: Codable {
    public let location: CLLocation
    
    public init(location: CLLocation) { self.location = location }
    
    public init(coordinate: CLLocationCoordinate2D, altitude: CLLocationDistance, horizontalAccuracy hAccuracy: CLLocationAccuracy, verticalAccuracy vAccuracy: CLLocationAccuracy, course: CLLocationDirection, speed: CLLocationSpeed, timestamp: Date) {
        
        self.location = CLLocation(coordinate: coordinate, altitude: altitude, horizontalAccuracy: hAccuracy, verticalAccuracy: vAccuracy, course: course, speed: speed, timestamp: timestamp)
    }
    
    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.location = CLLocation(latitude: latitude, longitude: longitude)
    }
    
    public init(coordinate: CLLocationCoordinate2D, altitude: CLLocationDistance, horizontalAccuracy hAccuracy: CLLocationAccuracy, verticalAccuracy vAccuracy: CLLocationAccuracy, timestamp: Date) {
        
        self.location = CLLocation(coordinate: coordinate, altitude: altitude, horizontalAccuracy: hAccuracy, verticalAccuracy: vAccuracy, timestamp: timestamp)
    }
    
    public init(from decoder: Decoder) throws {
        let data = try decoder.singleValueContainer().decode(Data.self)
        guard let value = NSKeyedUnarchiver.unarchiveObject(with: data) as? CLLocation else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize CKLocation from invalid data value \(data)"))
        }
        
        self.location = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(NSKeyedArchiver.archivedData(withRootObject: location))
    }
}

extension CLLocation {
    var codableLocation: CodableLocation { return CodableLocation(location: self) }
}

public struct CodableImage: Codable {
    public let image: UIImage
    
    public var imageData: Data? {
        return UIImagePNGRepresentation(image)
    }
    
    public init(image: UIImage) { self.image = image }
    
    init?(named name: String, in bundle: Bundle? = nil, compatibleWith traitCollection: UITraitCollection? = nil) {
        guard let image = UIImage.init(named: name, in: bundle, compatibleWith: traitCollection) else { return nil }
        
        self.image = image
    }
    
    init?(contentsOfFile path: String) {
        guard let image = UIImage.init(contentsOfFile: path) else { return nil }
        
        self.image = image
    }
    
    init?(data: Data) {
        guard let image = UIImage.init(data: data) else { return nil }
        
        self.image = image
    }
    
    init?(data: Data, scale: CGFloat) {
        guard let image = UIImage.init(data: data, scale: scale) else { return nil }
        
        self.image = image
    }
    
    init(imageLiteralResourceName name: String) { self.image = UIImage.init(imageLiteralResourceName: name) }
    init(cgImage: CGImage) { self.image = UIImage.init(cgImage: cgImage) }
    init(cgImage: CGImage, scale: CGFloat, orientation: UIImageOrientation) { self.image = UIImage.init(cgImage: cgImage, scale: scale, orientation: orientation) }
    init(ciImage: CIImage) { self.image = UIImage.init(ciImage: ciImage) }
    init(ciImage: CIImage, scale: CGFloat, orientation: UIImageOrientation)  { self.image = UIImage.init(ciImage: ciImage, scale: scale, orientation: orientation) }
    
    public init(from decoder: Decoder) throws {
        let data = try decoder.singleValueContainer().decode(Data.self)
        guard let value = UIImage(data: data) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot initialize CLLocation from invalid data value \(data)"))
        }
        
        self.image = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let value = self.imageData else {
            throw EncodingError.invalidValue(image, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode UIImage from value \(image)"))
        }
        
        try container.encode(value)
    }
}

extension UIImage {
    var codableImage: CodableImage { return CodableImage(image: self) }
}

public struct CloudKitInformation {
    weak var zone: Zone?
    var record: CKRecord?
    
    var recordID: CKRecordID? {
        return self.record?.recordID
    }
    
    var recordType: String? {
        return self.record?.recordType
    }
    
    var creationDate: Date? {
        return self.record?.creationDate
    }
    
    var creatorUserRecordID: CKRecordID? {
        return self.record?.creatorUserRecordID
    }
    
    var modificationDate: Date? {
        return self.record?.modificationDate
    }
    
    var lastModifiedUserRecordID: CKRecordID? {
        return self.record?.lastModifiedUserRecordID
    }
    
    var recordChangeTag: String? {
        return self.record?.recordChangeTag
    }
}


protocol CloudKitDecodable: Decodable {
    var cloudInformation: CloudKitInformation? { get set }
}

protocol CloudKitEncodable: Encodable {
    var recordType: String { get }
    var cloudInformation: CloudKitInformation? { get set }
}

typealias CloudKitCodable = CloudKitEncodable & CloudKitDecodable


class Zone {
    static let defaultZoneName = "DefaultCKWrapperZone"
    static let key = CodingUserInfoKey(rawValue: "Zone_CloudKitWrapper_WeakReferenceObject")!
    
    fileprivate var existingFetchedRecords: [CKRecord] = []
    
    enum DatabaseAccessibility {
        case `private`
        case `public`
    }
    
    fileprivate let container: CKContainer
    fileprivate let database: CKDatabase
    fileprivate let zone: CKRecordZone?
    
    // MARK: - Options
    
    var saveTimeoutIntervalForRequest: TimeInterval = 10.0
    var saveTimeoutIntervalForResource: TimeInterval = 30.0
    
    // MARK: - CKRecord Cache
    fileprivate var cachedSavedRecords: [CKRecordID: CKRecord] = [:]
    
    // MARK: - Private initializers
    
    fileprivate init(container: CKContainer, database: CKDatabase, zone: CKRecordZone? = nil) {
        self.container = container
        self.database = database
        self.zone = zone
    }
    
    fileprivate init(identifier containerIdentifier: String, database: CKDatabase, zoneName: String) {
        container = CKContainer(identifier: containerIdentifier)
        self.database = database
        zone = CKRecordZone(zoneName: zoneName)
    }
    
    // MARK: - Factory Methods
    
    static func defaultPublicDatabase() -> Zone {
        return Zone(container: CKContainer.default(), database: CKContainer.default().publicCloudDatabase)
    }
    
    static func defaultPrivateDatabase(with zoneName: String = Zone.defaultZoneName, completionHandler: @escaping (Zone?, Error?) -> Void) {
        let zone = Zone(container: CKContainer.default(), database: CKContainer.default().privateCloudDatabase, zone: CKRecordZone(zoneName: zoneName))
        
        guard let recordZone = zone.zone else { return }
        
        zone.database.save(recordZone) { (_recordZone, error) in
            if let _recordZone = _recordZone, recordZone.zoneID == _recordZone.zoneID {
                completionHandler(zone, error)
            }
            
            completionHandler(nil, error)
        }
    }
    
    static func publicDatabase(with containerIdentifier: String) -> Zone {
        let container = CKContainer(identifier: containerIdentifier)
        return Zone(container: container, database: container.publicCloudDatabase)
    }
    
    static func privateDatabase(in containerIdentifier: String, with zoneName: String = Zone.defaultZoneName, completionHandler: @escaping (Zone?, Error?) -> Void) {
        let container = CKContainer(identifier: containerIdentifier)
        let zone = Zone(container: container, database: container.privateCloudDatabase, zone: CKRecordZone(zoneName: zoneName))
        
        guard let recordZone = zone.zone else { return }
        
        zone.database.save(recordZone) { (_recordZone, error) in
            if let _recordZone = _recordZone, recordZone.zoneID == _recordZone.zoneID {
                completionHandler(zone, error)
            }
            
            completionHandler(nil, error)
        }
    }
    
    // MARK: - CRUD Functions
    
    // MARK: Create and Update
    
    func save<T: CloudKitEncodable>(_ objects: T, completionHandler: @escaping (Error?) -> Void) {
        do {
            let encoder = CloudKitEncoder()
            encoder.zoneID = zone?.zoneID
            let records = try encoder.encode(objects)
            
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            
            operation.configuration = {
                let configuration = CKOperationConfiguration()
                
                configuration.timeoutIntervalForRequest = self.saveTimeoutIntervalForRequest
                configuration.timeoutIntervalForResource = self.saveTimeoutIntervalForResource
                
                return configuration
            }()
            
            operation.modifyRecordsCompletionBlock = { (records, _, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        completionHandler(error)
                    } else if let records = records {
                        self.cachedSavedRecords = records.reduce(into: self.cachedSavedRecords, { $0[$1.recordID] = $1 })
                        completionHandler(nil)
                    } else {
                        completionHandler(nil)
                    }
                }
            }
            
            database.add(operation)
        } catch {
            completionHandler(error)
        }
        
    }
    
    // MARK: Read
    
    func retrieveObjects<T: CloudKitDecodable>(with predicate: NSPredicate = NSPredicate(value: true), completionHandler: @escaping ([T]) -> Void) {
        retrieveRecords(for: String(describing: T.self), with: predicate) { (records, error) in
            if error != nil {
                print(error!)
                completionHandler([])
            } else {
                let decoder = CloudKitDecoder()
                decoder.userInfo = [ Zone.key : self ]
                
                do {
                    completionHandler(try decoder.decode([T].self, from: records))
                } catch {
                    
                    print(error)
                    
                    completionHandler([])
                }
            }
        }
    }
    
    fileprivate func retrieveRecords(for recordType: String, with predicate: NSPredicate = NSPredicate(value: true), completionHandler: @escaping ([CKRecord], Error?) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        var cachedRecords = self.cachedSavedRecords.filter({ $1.recordType == recordType && predicate.evaluate(with: $1) })
        
        database.perform(query, inZoneWith: zone?.zoneID) { (cloudRecords, error) in
            DispatchQueue.main.async {
                if let cloudRecords = cloudRecords {
                    cloudRecords.forEach({ cachedRecords[$0.recordID] = $0 })
                    
                    completionHandler(Array(cachedRecords.values), error)
                } else {
                    completionHandler([], error)
                }
            }
        }
    }
    
    // MARK: Delete
    
    func delete<T: CloudKitEncodable>(object: T, completionHandler: @escaping (Error?) -> Void) {
        do {
            let encoder = CloudKitEncoder()
            encoder.zoneID = zone?.zoneID
            let records = try encoder.encode(object).map({ $0.recordID })
            
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: records)
            
            operation.configuration = {
                let configuration = CKOperationConfiguration()
                
                configuration.timeoutIntervalForRequest = self.saveTimeoutIntervalForRequest
                
                return configuration
            }()
            
            operation.modifyRecordsCompletionBlock = { (_, recordIDs, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        completionHandler(error)
                    } else if let recordIDs = recordIDs {
                        self.cachedSavedRecords = recordIDs.reduce(into: self.cachedSavedRecords, { $0[$1] = nil })
                        completionHandler(nil)
                    } else {
                        completionHandler(nil)
                    }
                }
            }
            
            database.add(operation)
        } catch {
            completionHandler(error)
        }
    }
    
    // MARK: User Information
    
    struct User {
        var firstName: String?
        var lastName: String?
        var phoneNumber: String?
        var emailAddress: String?
        
        init(userId: CKUserIdentity) {
            self.firstName = userId.nameComponents?.givenName
            self.lastName  = userId.nameComponents?.familyName
            self.phoneNumber = userId.lookupInfo?.emailAddress
            self.emailAddress = userId.lookupInfo?.emailAddress
        }
    }
    
    func userInformation(completionHandler: @escaping (User?, Error?) -> Void) {
        self.container.requestApplicationPermission(.userDiscoverability) { (status, error) in
            self.container.fetchUserRecordID(completionHandler: { (record, error) in
                if let record = record {
                    self.container.discoverUserIdentity(withUserRecordID: record, completionHandler: { (userID, error) in
                        if let userID = userID {
                            completionHandler(Zone.User(userId: userID), nil)
                        } else {
                            completionHandler(nil , error)
                        }
                    })
                } else {
                    completionHandler(nil , error)
                }
            })
        }
    }
}

//===----------------------------------------------------------------------===//
// CloudKit Decoder
//===----------------------------------------------------------------------===//

/// `CloudKitDecoder` facilitates the decoding of CloudKit records into semantic `Decodable` types.
open class CloudKitDecoder {
    // MARK: Options
    
    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey : Any] = [:]
    
    /// Options set on the top-level encoder to pass down the decoding hierarchy.
    fileprivate struct _Options {
        let userInfo: [CodingUserInfoKey : Any]
    }
    
    /// The options set on the top-level decoder.
    fileprivate var options: _Options {
        return _Options(userInfo: userInfo)
    }
    
    // MARK: - Constructing a CloudKit Decoder
    
    /// Initializes `self` with default strategies.
    public init() {}
    
    // MARK: - Decoding Values
    
    /// Decodes a top-level value of the given type from the given property list representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter records: The records to decode from.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not a valid property list.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T : Decodable>(_ type: T.Type, from records: [CKRecord]) throws -> T {
        guard !records.isEmpty else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given value did not contain any records."))
        }
        
        guard let topLevel = CloudKitSerialization.object(from: records) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid Cloudkit Records."))
        }
        
        let decoder = _CKDecoder(referencing: topLevel, options: self.options, records: records.reduce(into: [:], { $0[$1.recordID.recordName] = $1 }))
        
        guard let value = try decoder.unbox(topLevel, as: type) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
        }
        
        return value
    }
}

// MARK: - _CKDecoder

fileprivate class _CKDecoder : Decoder {
    // MARK: Properties
    
    /// The records being decoded by the decoder.
    fileprivate(set) fileprivate var records: [String: CKRecord]
    
    /// The decoder's storage.
    fileprivate var storage: _CKDecodingStorage
    
    /// Options set on the top-level decoder.
    fileprivate let options: CloudKitDecoder._Options
    
    /// The path to the current point in encoding.
    fileprivate(set) public var codingPath: [CodingKey]
    
    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }
    
    // MARK: - Initialization
    
    /// Initializes `self` with the given top-level container and options.
    fileprivate init(referencing container: Any, at codingPath: [CodingKey] = [], options: CloudKitDecoder._Options, records: [String: CKRecord]) {
        self.storage = _CKDecodingStorage()
        self.storage.push(container: container)
        self.codingPath = codingPath
        self.options = options
        self.records = records
    }
    
    // MARK: - Decoder Methods

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard !(self.storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<Key>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }
        
        guard let topContainer = self.storage.topContainer as? [String : Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: self.storage.topContainer)
        }
        
        let container = _CKKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !(self.storage.topContainer is NSNull) else {
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get unkeyed decoding container -- found null value instead."))
        }
        
        let topContainer: [Any]
        
        if let container = self.storage.topContainer as? [Any] {
            topContainer = container
        } else if let container = self.storage.topContainer as? [AnyHashable: Any]  {
            topContainer = [container]
        } else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [Any].self, reality: self.storage.topContainer)
        }
        
        return _CKUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

// MARK: Decoding Containers

fileprivate struct _CKKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K
    
    // MARK: Properties
    
    /// A reference to the decoder we're reading from.
    private let decoder: _CKDecoder
    
    /// A reference to the container we're reading from.
    private let container: [String : Any]
    
    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _CKDecoder, wrapping container: [String : Any]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }
    
    // MARK: - KeyedDecodingContainerProtocol Methods
    
    public var allKeys: [Key] {
        return self.container.keys.flatMap { Key(stringValue: $0) }
    }
    
    public func contains(_ key: Key) -> Bool {
        return self.container[key.stringValue] != nil
    }
    
    func decodeNil(forKey key: K) throws -> Bool {
        if let entry = self.container[key.stringValue] {
            return entry is NSNull
        } else {
            return true
        }
    }
    
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Int64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: UInt64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        guard let value = try self.decoder.unbox(entry, as: Float.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: Double.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let entry = self.container[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: String.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let entry = self.container[key.stringValue] else {
            let parsedType = String(describing: type).components(separatedBy: "<").first!
            
            switch parsedType {
            case "Array":
                return [] as! T
            case "Dictionary":
                return [:] as! T
            default:
                throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
            }
        }
        
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = try self.decoder.unbox(entry, as: type) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
        }
        
        return value
    }
    
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = self.container[key.stringValue] else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get nested keyed container -- no value found for key \"\(key.stringValue)\""))
        }
        
        guard let dictionary = value as? [String : Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: value)
        }
        
        let container = _CKKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
        return KeyedDecodingContainer(container)
    }
    
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        guard let value = self.container[key.stringValue] else {
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get nested unkeyed container -- no value found for key \"\(key.stringValue)\""))
        }
        
        guard let array = value as? [Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [Any].self, reality: value)
        }
        
        return _CKUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
    }
    
    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        self.decoder.codingPath.append(key)
        defer { self.decoder.codingPath.removeLast() }
        
        let value: Any = self.container[key.stringValue] ?? NSNull()
        return _CKDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options, records: self.decoder.records)
    }
    
    public func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: _CloudkitKey.super)
    }
    
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}

fileprivate struct _CKUnkeyedDecodingContainer : UnkeyedDecodingContainer {
    // MARK: Properties
    
    /// A reference to the decoder we're reading from.
    private let decoder: _CKDecoder
    
    /// A reference to the container we're reading from.
    private let container: [Any]
    
    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]
    
    /// The index of the element we're about to decode.
    private(set) public var currentIndex: Int
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _CKDecoder, wrapping container: [Any]) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
    }
    
    // MARK: - UnkeyedDecodingContainer Methods
    
    public var count: Int? {
        return self.container.count
    }
    
    public var isAtEnd: Bool {
        return self.currentIndex >= self.count!
    }
    
    public mutating func decodeNil() throws -> Bool {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(Any?.self, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        if self.container[self.currentIndex] is NSNull {
            self.currentIndex += 1
            return true
        } else {
            return false
        }
    }
    
    public mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Bool.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Int.Type) throws -> Int {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: UInt.Type) throws -> UInt {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt8.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt16.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt32.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt64.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Float.Type) throws -> Float {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Float.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: Double.Type) throws -> Double {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Double.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode(_ type: String.Type) throws -> String {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: String.self) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func decode<T : Decodable>(_ type: T.Type) throws -> T {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: type) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_CloudkitKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
        }
        
        self.currentIndex += 1
        return decoded
    }
    
    public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
        }
        
        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }
        
        guard let dictionary = value as? [String : Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: value)
        }
        
        self.currentIndex += 1
        let container = _CKKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: dictionary)
        return KeyedDecodingContainer(container)
    }
    
    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get nested unkeyed container -- unkeyed container is at end."))
        }
        
        let value = self.container[self.currentIndex]
        guard !(value is NSNull) else {
            throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                              DecodingError.Context(codingPath: self.codingPath,
                                                                    debugDescription: "Cannot get keyed decoding container -- found null value instead."))
        }
        
        guard let array = value as? [Any] else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: [Any].self, reality: value)
        }
        
        self.currentIndex += 1
        return _CKUnkeyedDecodingContainer(referencing: self.decoder, wrapping: array)
    }
    
    public mutating func superDecoder() throws -> Decoder {
        self.decoder.codingPath.append(_CloudkitKey(index: self.currentIndex))
        defer { self.decoder.codingPath.removeLast() }
        
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(Decoder.self, DecodingError.Context(codingPath: self.codingPath,
                                                                                  debugDescription: "Cannot get superDecoder() -- unkeyed container is at end."))
        }
        
        let value = self.container[self.currentIndex]
        self.currentIndex += 1
        return _CKDecoder(referencing: value, at: self.decoder.codingPath, options: self.decoder.options, records: self.decoder.records)
    }
}

extension _CKDecoder : SingleValueDecodingContainer {
    // MARK: SingleValueDecodingContainer Methods
    
    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected \(type) but found null value instead."))
        }
    }
    
    func decodeNil() -> Bool {
        return self.storage.topContainer is NSNull
    }
    
    public func decode(_ type: Bool.Type) throws -> Bool {
        try expectNonNull(Bool.self)
        return try self.unbox(self.storage.topContainer, as: Bool.self)!
    }
    
    public func decode(_ type: Int.Type) throws -> Int {
        try expectNonNull(Int.self)
        return try self.unbox(self.storage.topContainer, as: Int.self)!
    }
    
    public func decode(_ type: Int8.Type) throws -> Int8 {
        try expectNonNull(Int8.self)
        return try self.unbox(self.storage.topContainer, as: Int8.self)!
    }
    
    public func decode(_ type: Int16.Type) throws -> Int16 {
        try expectNonNull(Int16.self)
        return try self.unbox(self.storage.topContainer, as: Int16.self)!
    }
    
    public func decode(_ type: Int32.Type) throws -> Int32 {
        try expectNonNull(Int32.self)
        return try self.unbox(self.storage.topContainer, as: Int32.self)!
    }
    
    public func decode(_ type: Int64.Type) throws -> Int64 {
        try expectNonNull(Int64.self)
        return try self.unbox(self.storage.topContainer, as: Int64.self)!
    }
    
    public func decode(_ type: UInt.Type) throws -> UInt {
        try expectNonNull(UInt.self)
        return try self.unbox(self.storage.topContainer, as: UInt.self)!
    }
    
    public func decode(_ type: UInt8.Type) throws -> UInt8 {
        try expectNonNull(UInt8.self)
        return try self.unbox(self.storage.topContainer, as: UInt8.self)!
    }
    
    public func decode(_ type: UInt16.Type) throws -> UInt16 {
        try expectNonNull(UInt16.self)
        return try self.unbox(self.storage.topContainer, as: UInt16.self)!
    }
    
    public func decode(_ type: UInt32.Type) throws -> UInt32 {
        try expectNonNull(UInt32.self)
        return try self.unbox(self.storage.topContainer, as: UInt32.self)!
    }
    
    public func decode(_ type: UInt64.Type) throws -> UInt64 {
        try expectNonNull(UInt64.self)
        return try self.unbox(self.storage.topContainer, as: UInt64.self)!
    }
    
    public func decode(_ type: Float.Type) throws -> Float {
        try expectNonNull(Float.self)
        return try self.unbox(self.storage.topContainer, as: Float.self)!
    }
    
    public func decode(_ type: Double.Type) throws -> Double {
        try expectNonNull(Double.self)
        return try self.unbox(self.storage.topContainer, as: Double.self)!
    }
    
    public func decode(_ type: String.Type) throws -> String {
        try expectNonNull(String.self)
        return try self.unbox(self.storage.topContainer, as: String.self)!
    }
    
    public func decode<T : Decodable>(_ type: T.Type) throws -> T {
        try expectNonNull(type)
        return try self.unbox(self.storage.topContainer, as: type)!
    }
}

// MARK: - Concrete Value Representations

extension _CKDecoder {
    /// Returns the given value unboxed from a container.
    fileprivate func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
        guard !(value is NSNull) else { return nil }
        
        if let number = value as? NSNumber {
            // TODO: Add a flag to coerce non-boolean numbers into Bools?
            if number === kCFBooleanTrue as NSNumber {
                return true
            } else if number === kCFBooleanFalse as NSNumber {
                return false
            }
        }
        
        throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
    }
    
    fileprivate func unbox(_ value: Any, as type: Int.Type) throws -> Int? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let int = number.intValue
        guard NSNumber(value: int) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return int
    }
    
    fileprivate func unbox(_ value: Any, as type: Int8.Type) throws -> Int8? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let int8 = number.int8Value
        guard NSNumber(value: int8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return int8
    }
    
    fileprivate func unbox(_ value: Any, as type: Int16.Type) throws -> Int16? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let int16 = number.int16Value
        guard NSNumber(value: int16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return int16
    }
    
    fileprivate func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let int32 = number.int32Value
        guard NSNumber(value: int32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return int32
    }
    
    fileprivate func unbox(_ value: Any, as type: Int64.Type) throws -> Int64? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let int64 = number.int64Value
        guard NSNumber(value: int64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return int64
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt.Type) throws -> UInt? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let uint = number.uintValue
        guard NSNumber(value: uint) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return uint
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt8.Type) throws -> UInt8? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let uint8 = number.uint8Value
        guard NSNumber(value: uint8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return uint8
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt16.Type) throws -> UInt16? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let uint16 = number.uint16Value
        guard NSNumber(value: uint16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return uint16
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt32.Type) throws -> UInt32? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let uint32 = number.uint32Value
        guard NSNumber(value: uint32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return uint32
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt64.Type) throws -> UInt64? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let uint64 = number.uint64Value
        guard NSNumber(value: uint64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return uint64
    }
    
    fileprivate func unbox(_ value: Any, as type: Float.Type) throws -> Float? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let float = number.floatValue
        guard NSNumber(value: float) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return float
    }
    
    fileprivate func unbox(_ value: Any, as type: Double.Type) throws -> Double? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber, number !== kCFBooleanTrue, number !== kCFBooleanFalse else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        let double = number.doubleValue
        guard NSNumber(value: double) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed CloudKit number <\(number)> does not fit in \(type)."))
        }
        
        return double
    }
    
    fileprivate func unbox(_ value: Any, as type: String.Type) throws -> String? {
        guard !(value is NSNull) else { return nil }
        
        guard let string = value as? String else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        return string
    }
    
    fileprivate func unbox(_ value: Any, as type: Date.Type) throws -> Date? {
        guard !(value is NSNull) else { return nil }
        
        guard let date = value as? Date else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        return date
    }
    
    fileprivate func unbox(_ value: Any, as type: Data.Type) throws -> Data? {
        guard !(value is NSNull) else { return nil }
        
        guard let asset = value as? CKAsset else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        do {
            return try Data.init(contentsOf: asset.fileURL)
        } catch {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Expected to decode \(type) but found \(DecodingError._typeDescription(of: value)) instead.", underlyingError: error))
        }
    }
    
    fileprivate func unbox(_ value: Any, as type: CodableLocation.Type) throws -> CodableLocation? {
        guard !(value is NSNull) else { return nil }
        
        guard let location = value as? CLLocation else {
            throw DecodingError._typeMismatch(at: self.codingPath, expectation: type, reality: value)
        }
        
        return CodableLocation(location: location)
    }
    
    fileprivate func unbox(_ value: Any, as type: CodableImage.Type) throws -> CodableImage? {
        guard !(value is NSNull) else { return nil }
        
        guard let data = try self.unbox(value, as: Data.self) else { return nil }
        
        return CodableImage(data: data)
    }
    
    fileprivate func unbox<T : Decodable>(_ value: Any, as type: T.Type) throws -> T? {
        let decoded: T
        if type == Date.self || type == NSDate.self {
            guard let date = try self.unbox(value, as: Date.self) else { return nil }
            decoded = date as! T
        } else if type == Data.self || type == NSData.self {
            guard let data = try self.unbox(value, as: Data.self) else { return nil }
            decoded = data as! T
        } else if T.self == CodableLocation.self {
            guard let location = try self.unbox(value, as: CodableLocation.self) else { return nil }
            decoded = location as! T
        } else if T.self == CodableImage.self {
            guard let image = try self.unbox(value, as: CodableImage.self) else { return nil }
            decoded = image as! T
        } else {
            self.storage.push(container: value)
            decoded = try type.init(from: self)
            self.storage.popContainer()
        }
        
        return decoded
    }
}

extension CloudKitInformation: Decodable {
    public init(from decoder: Decoder) throws {
        if let decoder = decoder as? _CKDecoder {
            let recordName = try decoder.singleValueContainer().decode(String.self)
            self.zone = decoder.userInfo[Zone.key] as? Zone
            self.record = decoder.records[recordName]
        } else {
            self.zone = nil
            self.record = nil
        }
    }
}

// MARK: - Decoding Storage

fileprivate struct _CKDecodingStorage {
    // MARK: Properties
    
    /// The container stack.
    /// Elements may be any one of the plist types (NSNull, NSNumber, NSString, NSDate, NSData, NSArray, NSDictionary, CLLocation, CKAsset, CKReference).
    private(set) fileprivate var containers: [Any] = []
    
    // MARK: - Initialization
    
    /// Initializes `self` with no containers.
    fileprivate init() {}
    
    // MARK: - Modifying the Stack
    
    fileprivate var count: Int {
        return self.containers.count
    }
    
    fileprivate var topContainer: Any {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.last!
    }
    
    fileprivate mutating func push(container: Any) {
        self.containers.append(container)
    }
    
    fileprivate mutating func popContainer() {
        precondition(self.containers.count > 0, "Empty container stack.")
        self.containers.removeLast()
    }
}

//===----------------------------------------------------------------------===//
// Error Utilities
//===----------------------------------------------------------------------===//

fileprivate extension DecodingError {
    /// Returns a `.typeMismatch` error describing the expected type.
    ///
    /// - parameter path: The path of `CodingKey`s taken to decode a value of this type.
    /// - parameter expectation: The type expected to be encountered.
    /// - parameter reality: The value that was encountered instead of the expected type.
    /// - returns: A `DecodingError` with the appropriate path and debug description.
    fileprivate static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: Any) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(_typeDescription(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    /// Returns a description of the type of `value` appropriate for an error message.
    ///
    /// - parameter value: The value whose type to describe.
    /// - returns: A string describing `value`.
    /// - precondition: `value` is one of the types below.
    fileprivate static func _typeDescription(of value: Any) -> String {
        if value is NSNull {
            return "a null value"
        } else if value is NSNumber /* FIXME: If swift-corelibs-foundation isn't updated to use NSNumber, this check will be necessary: || value is Int || value is Double */ {
            return "a number"
        } else if value is String {
            return "a string/data"
        } else if value is [Any] {
            return "an array"
        } else if value is [String : Any] {
            return "a dictionary"
        } else {
            return "\(type(of: value))"
        }
    }
}

//===----------------------------------------------------------------------===//
// CloudKitEncoder Encoder
//===----------------------------------------------------------------------===//

/// `CloudKitEncoder` facilitates the encoding of `Encodable` values into CKRecords.
open class CloudKitEncoder {
    
    // MARK: - Options
    
    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey : Any] = [:]
    
    open var zoneID: CKRecordZoneID? = nil
    
    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let userInfo: [CodingUserInfoKey : Any]
        let zoneID: CKRecordZoneID?
    }
    
    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(userInfo: userInfo, zoneID: zoneID)
    }
    
    // MARK: - Constructing a CloudKit Encoder
    
    /// Initializes `self` with default strategies.
    public init() {}
    
    // MARK: - Encoding Values
    
    /// Encodes the given top-level value and returns its record representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: An array of `CKRecord` values containing the encoded representation of value.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<Value : Encodable>(_ value: Value) throws -> [CKRecord] {
        let recordType: String
        
        if let value = value as? CloudKitEncodable {
            recordType = value.recordType
        } else {
            recordType = String(describing: Value.self)
        }
        
        return try _encode(value, with: recordType)
    }
    
    /// Encodes the given top-level value and returns its record representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: An array of `CKRecord` values containing the encoded representation of value.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<Value : Encodable>(_ value: [Value]) throws -> [CKRecord] {
        var records: [CKRecord] = []
        
        for value in value {
            if let value = value as? Dictionary<AnyHashable, Encodable> {
                records += try encode(value)
            } else if let value = value as? Array<Encodable> {
                records += try encode(value)
            } else if let value = value as? Set<AnyHashable> {
                records += try encode(value)
            } else {
                let recordType: String
                
                if let value = value as? CloudKitEncodable {
                    recordType = value.recordType
                } else {
                    recordType = String(describing: Value.self)
                }
                
                records += try _encode(value, with: recordType)
            }
        }
        
        return records
    }
    
    fileprivate func _encode<Value : Encodable>(_ value: Value, with type: String) throws -> [CKRecord] {
        let encoder = _CKEncoder(options: self.options)
        
        guard let topLevel = try encoder.box_(value) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) did not encode any values."))
        }
        
        if topLevel is NSNull {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as null CloudKit fragment."))
        } else if topLevel is NSNumber {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as number CloudKit fragment."))
        } else if topLevel is NSString {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as string CloudKit fragment."))
        } else if topLevel is NSDate {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as date CloudKit fragment."))
        } else if topLevel is NSData {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as data CloudKit fragment."))
        } else if topLevel is CLLocation {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as location CloudKit fragment."))
        } else if topLevel is CKAsset || topLevel is UIImage {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as asset CloudKit fragment."))
        } else if topLevel is CKReference {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(Value.self) encoded as reference CloudKit fragment."))
        }
        
        return CloudKitSerialization.records(fromObject: topLevel, withType: type, withZoneID: self.zoneID, retrieveExistingRecord: { (dict) -> CKRecord? in
            return (value as? CloudKitEncodable)?.cloudInformation?.record
        })
    }
}

extension Array {
    var ElementType: Element.Type {
        return Element.self
    }
}

fileprivate class _CKEncoder: Encoder {
    // MARK: Properties
    
    /// The encoder's storage.
    fileprivate var storage: _CKEncodingStorage
    
    /// Options set on the top-level encoder.
    fileprivate let options: CloudKitEncoder._Options
    
    /// The path to the current point in encoding.
    fileprivate(set) public var codingPath: [CodingKey]
    
    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }
    
    // MARK: - Initialization
    
    /// Initializes `self` with the given top-level encoder options.
    fileprivate init(options: CloudKitEncoder._Options, codingPath: [CodingKey] = []) {
        self.options = options
        self.storage = _CKEncodingStorage()
        self.codingPath = codingPath
    }
    
    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
    fileprivate var canEncodeNewValue: Bool {
        // Every time a new value gets encoded, the key it's encoded for is pushed onto the coding path (even if it's a nil key from an unkeyed container).
        // At the same time, every time a container is requested, a new value gets pushed onto the storage stack.
        // If there are more values on the storage stack than on the coding path, it means the value is requesting more than one container, which violates the precondition.
        //
        // This means that anytime something that can request a new container goes onto the stack, we MUST push a key onto the coding path.
        // Things which will not request containers do not need to have the coding path extended for them (but it doesn't matter if it is, because they will not reach here).
        return self.storage.count == self.codingPath.count
    }
    
    // MARK: - Encoder Methods
    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        // If an existing keyed container was already requested, return that one.
        let topContainer: NSMutableDictionary
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }
            
            topContainer = container
        }
        
        let container = _CKKeyedEncodingContainer<Key>(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }
    
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: NSMutableArray
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }
            
            topContainer = container
        }
        
        return _CKUnkeyedEncodingContainer(referencing: self, codingPath: self.codingPath, wrapping: topContainer)
    }
    
    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

fileprivate struct _CKKeyedEncodingContainer<K : CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K
    
    // MARK: Properties
    
    /// A reference to the encoder we're writing to.
    private let encoder: _CKEncoder
    
    /// A reference to the container we're writing to.
    private let container: NSMutableDictionary
    
    /// The path of coding keys taken to get to this point in encoding.
    private(set) public var codingPath: [CodingKey]
    
    // MARK: - Initialization
    
    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _CKEncoder, codingPath: [CodingKey], wrapping container: NSMutableDictionary) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }
    
    public mutating func encodeNil(forKey key: Key)               throws { self.container[key.stringValue] = NSNull() }
    public mutating func encode(_ value: Bool, forKey key: Key)   throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Int, forKey key: Key)    throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Int8, forKey key: Key)   throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Int16, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Int32, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Int64, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: UInt, forKey key: Key)   throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: UInt8, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: String, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Float, forKey key: Key)  throws { self.container[key.stringValue] = self.encoder.box(value) }
    public mutating func encode(_ value: Double, forKey key: Key) throws { self.container[key.stringValue] = self.encoder.box(value) }
    
    mutating func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        self.encoder.codingPath.append(key)
        defer { self.encoder.codingPath.removeLast() }
        self.container[key.stringValue] = try self.encoder.box(value)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let dictionary = NSMutableDictionary()
        self.container[key.stringValue] = dictionary
        
        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }
        
        let container = _CKKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let array = NSMutableArray()
        self.container[key.stringValue] = array
        
        self.codingPath.append(key)
        defer { self.codingPath.removeLast() }
        return _CKUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }
    
    mutating func superEncoder() -> Encoder {
        return _CKReferencingEncoder(referencing: self.encoder, at: _CloudkitKey.super, wrapping: self.container)
    }
    
    mutating func superEncoder(forKey key: K) -> Encoder {
        return _CKReferencingEncoder(referencing: self.encoder, at: key, wrapping: self.container)
    }
}

fileprivate struct _CKUnkeyedEncodingContainer : UnkeyedEncodingContainer {
    // MARK: Properties
    
    /// A reference to the encoder we're writing to.
    private let encoder: _CKEncoder
    
    /// A reference to the container we're writing to.
    private let container: NSMutableArray
    
    /// The path of coding keys taken to get to this point in encoding.
    private(set) public var codingPath: [CodingKey]
    
    /// The number of elements encoded into the container.
    public var count: Int {
        return self.container.count
    }
    
    // MARK: - Initialization
    
    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: _CKEncoder, codingPath: [CodingKey], wrapping container: NSMutableArray) {
        self.encoder = encoder
        self.codingPath = codingPath
        self.container = container
    }
    
    // MARK: - UnkeyedEncodingContainer Methods
    
    public mutating func encodeNil()             throws { self.container.add(NSNull()) }
    public mutating func encode(_ value: Bool)   throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int)    throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int8)   throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int16)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int32)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int64)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt)   throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt8)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt16) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt32) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt64) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Float)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Double) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: String) throws { self.container.add(self.encoder.box(value)) }
    
    mutating func encode<T>(_ value: T) throws where T : Encodable {
        self.encoder.codingPath.append(_CloudkitKey(index: self.count))
        defer { self.encoder.codingPath.removeLast() }
        self.container.add(try self.encoder.box(value))
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        self.codingPath.append(_CloudkitKey(index: self.count))
        defer { self.codingPath.removeLast() }
        
        let dictionary = NSMutableDictionary()
        self.container.add(dictionary)
        
        let container = _CKKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPath: self.codingPath, wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        self.codingPath.append(_CloudkitKey(index: self.count))
        defer { self.codingPath.removeLast() }
        
        let array = NSMutableArray()
        self.container.add(array)
        return _CKUnkeyedEncodingContainer(referencing: self.encoder, codingPath: self.codingPath, wrapping: array)
    }
    
    mutating func superEncoder() -> Encoder {
        return _CKReferencingEncoder(referencing: self.encoder, at: self.container.count, wrapping: self.container)
    }
}

extension _CKEncoder: SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods
    
    private func assertCanEncodeNewValue() {
        precondition(self.canEncodeNewValue, "Attempt to encode value through single value container when previously value already encoded.")
    }
    
    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(container: NSNull())
    }
    
    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }
    
    public func encode<T : Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        try self.storage.push(container: self.box(value))
    }
}

// MARK: - Concrete Value Representations

extension _CKEncoder {
    
    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    fileprivate func box(_ value: Bool)   -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int)    -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int8)   -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int16)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int32)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Int64)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt)   -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt8)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt16) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt32) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: UInt64) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Float)  -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: Double) -> NSObject { return NSNumber(value: value) }
    fileprivate func box(_ value: String) -> NSObject { return NSString(string: value) }
    
    fileprivate func box<T : Encodable>(_ value: T) throws -> NSObject {
        return try self.box_(value) ?? NSDictionary()
    }
    
    fileprivate func box_<T : Encodable>(_ value: T) throws -> NSObject? {
        if T.self == Date.self || T.self == NSDate.self {
            // CloudKitSerialization handles NSDate directly.
            return (value as! NSDate)
        } else if T.self == Data.self || T.self == NSData.self {
            return CKAsset(data: value as? Data)
        } else if T.self == CodableLocation.self {
            // CloudKitSerialization handles CLLocation directly.
            return (value as! CodableLocation).location
        } else if T.self == CodableImage.self {
            return CKAsset(data: (value as! CodableImage).imageData)
        }
        
        // The value should request a container from the _PlistEncoder.
        let depth = self.storage.count
        try value.encode(to: self)

        // The top container should be a new container.
        guard self.storage.count > depth else {
            return nil
        }
        
        return self.storage.popContainer()
    }
}

fileprivate extension CKAsset {
    convenience init?(data: Data?) {
        guard let data = data else { return nil }
        
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        do {
            try data.write(to: fileURL)
            
            self.init(fileURL: fileURL)
        } catch {
            return nil
        }
    }
}

// MARK: - _CKReferencingEncoder

/// _CKReferencingEncoder is a special subclass of _CKEncoer which has its own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
fileprivate class _CKReferencingEncoder: _CKEncoder {
    // MARK: Reference types.
    
    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(NSMutableArray, Int)
        
        /// Referencing a specific key in a dictionary container.
        case dictionary(NSMutableDictionary, String)
    }
    
    // MARK: - Properties
    
    /// The encoder we're referencing.
    private let encoder: _CKEncoder
    
    /// The container reference itself.
    private let reference: Reference
    
    // MARK: - Initialization
    
    /// Initializes `self` by referencing the given array container in the given encoder.
    fileprivate init(referencing encoder: _CKEncoder, at index: Int, wrapping array: NSMutableArray) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPath: encoder.codingPath)
        
        self.codingPath.append(_CloudkitKey(index: index))
    }
    
    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    fileprivate init(referencing encoder: _CKEncoder, at key: CodingKey, wrapping dictionary: NSMutableDictionary) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, key.stringValue)
        super.init(options: encoder.options, codingPath: encoder.codingPath)
        
        self.codingPath.append(key)
    }
    
    // MARK: - Coding Path Operations
    
    fileprivate override var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }
    
    // MARK: - Deinitialization
    
    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value: Any
        switch self.storage.count {
        case 0: value = NSDictionary()
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }
        
        switch self.reference {
        case .array(let array, let index):
            array.insert(value, at: index)
            
        case .dictionary(let dictionary, let key):
            dictionary[NSString(string: key)] = value
        }
    }
}

extension CloudKitInformation: Encodable {
    public func encode(to encoder: Encoder) throws {
        if let encoder = encoder as? _CKEncoder,
            let record = record {
            var container = encoder.singleValueContainer()
            try container.encode(record.recordID.recordName)
        }
    }
}

// MARK: - Encoding Storage and Containers
fileprivate struct _CKEncodingStorage {
    // MARK: Properties
    /// The container stack.
    /// Elements may be any one of the cloudkit types (NSNull, NSNumber, NSString, NSDate, NSData, NSArray, NSDictionary, CLLocation, CKAsset, CKReference).
    private(set) fileprivate var containers: [NSObject] = []
    
    // MARK: - Initialization
    /// Initializes `self` with no containers.
    fileprivate init() {}
    
    // MARK: - Modifying the Stack
    fileprivate var count: Int {
        return self.containers.count
    }
    
    fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }
    
    fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        self.containers.append(array)
        return array
    }
    
    fileprivate mutating func push(container: NSObject) {
        self.containers.append(container)
    }
    
    fileprivate mutating func popContainer() -> NSObject {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}
