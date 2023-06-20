//
//  PersistenceController.swift
//  Cosmic Writer
//
//  Created by Personal on 18/06/2023.
//

import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentCloudKitContainer
    
    private init() {
        container = NSPersistentCloudKitContainer(name: "MessageDataModel")
        container.loadPersistentStores(completionHandler: { (storeDescription, error ) in
            if let error = error as NSError? {
                print(error)
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        try? container.viewContext.setQueryGenerationFrom(.current)
    }
}

