//
//  PhotosCollectionViewController.swift
//  Astronomy
//
//  Created by Andrew R Madsen on 9/5/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import UIKit

class PhotosCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        client.fetchMarsRover(named: "curiosity") { (rover, error) in
            if let error = error {
                NSLog("Error fetching info for curiosity: \(error)")
                return
            }
            
            self.roverInfo = rover
        }
    }
    
    // UICollectionViewDataSource/Delegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoReferences.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as? ImageCollectionViewCell ?? ImageCollectionViewCell()
        
        loadImage(forCell: cell, forItemAt: indexPath)
        
        return cell
    }
    
    // Make collection view cells fill as much available width as possible
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        var totalUsableWidth = collectionView.frame.width
        let inset = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        totalUsableWidth -= inset.left + inset.right
        
        let minWidth: CGFloat = 150.0
        let numberOfItemsInOneRow = Int(totalUsableWidth / minWidth)
        totalUsableWidth -= CGFloat(numberOfItemsInOneRow - 1) * flowLayout.minimumInteritemSpacing
        let width = totalUsableWidth / CGFloat(numberOfItemsInOneRow)
        return CGSize(width: width, height: width)
    }
    
    // Add margins to the left and right side
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10.0, bottom: 0, right: 10.0)
    }
    
    // MARK: - Private
    
    private func loadImage(forCell cell: ImageCollectionViewCell, forItemAt indexPath: IndexPath) {
        let photoReference = photoReferences[indexPath.item]
        
        
        
        if let cachedData = cache.value(for: photoReference.id) {
            DispatchQueue.main.async {
                guard let image = UIImage(data: cachedData) else { return }
                cell.imageView.image = image
            }
        }
        
//        URLSession.shared.dataTask(with: photoRequestURL) { (data, _, error) in
//
//            if let error = error {
//                print("Error: \(error)")
//                return
//            }
//
//            guard let data = data else { return }
//
//            self.cache.cache(value: data, for: photoReference.id)
//
//            guard let image = UIImage(data: data) else { return }
//
//            DispatchQueue.main.async {
//                let newIndicies = self.collectionView.indexPathsForVisibleItems
//                if newIndicies.contains(indexPath) {
//                    cell.imageView.image = image
//                }
//
//            }
//
//        }.resume()
        
        let fetchOp = FetchPhotoOperation(photoReference: photoReference)
        
        let cacheOp = BlockOperation {
            guard let data = fetchOp.imageData else { return }
            self.cache.cache(value: data, for: photoReference.id)
        }
        
        let uiOP = BlockOperation {
            guard let data = fetchOp.imageData else { return }
            
            let newIndices = self.collectionView.indexPathsForVisibleItems
            if newIndices.contains(indexPath) {
                let image = UIImage(data: data)
                cell.imageView.image = image
            }
        }
        
        cacheOp.addDependency(fetchOp)
        uiOP.addDependency(fetchOp)
        
        photoFetchQueue.addOperations([fetchOp, cacheOp, uiOP], waitUntilFinished: true)
        let mainQueue = OperationQueue.main
        mainQueue.addOperations([uiOP], waitUntilFinished: true)
        
    }
    
    // Properties
    
    private let photoFetchQueue = OperationQueue()
    private let client = MarsRoverClient()
    
    let cache = Cache<Int, Data>()
    
    
    private var roverInfo: MarsRover? {
        didSet {
            solDescription = roverInfo?.solDescriptions[100]
        }
    }
    private var solDescription: SolDescription? {
        didSet {
            if let rover = roverInfo,
                let sol = solDescription?.sol {
                client.fetchPhotos(from: rover, onSol: sol) { (photoRefs, error) in
                    if let e = error { NSLog("Error fetching photos for \(rover.name) on sol \(sol): \(e)"); return }
                    self.photoReferences = photoRefs ?? []
                }
            }
        }
    }
    private var photoReferences = [MarsPhotoReference]() {
        didSet {
            DispatchQueue.main.async { self.collectionView?.reloadData() }
        }
    }
    
    @IBOutlet var collectionView: UICollectionView!
}
