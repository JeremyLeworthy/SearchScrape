//
//  ViewController.swift
//  SearchScrape
//
//  Created by Jeremy Leworthy on 2021-02-13.
//

import UIKit
import Alamofire
import AlamofireImage
import SwiftSoup

class ImageResultsCVCell: UICollectionViewCell {
    @IBOutlet weak var btnImageResult: UIButton!
    
    @IBAction func cellTapped(_ sender: UIButton) {
        NotificationCenter.default.post(name: Notification.Name("viewFullScreenImage"), object: btnImageResult.backgroundImage(for: .normal))
    }
}

class WebResultsTableCell: UITableViewCell {
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    
    var link: String!
    
    @IBAction func visitWebsite(_ sender: UIButton) {
        if let url = URL(string: link) {
            UIApplication.shared.open(url)
        }
    }
}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var txtSearch: UITextField!
    @IBOutlet weak var btnSearch: UIButton!
    @IBOutlet weak var cvImageResults: UICollectionView!
    @IBOutlet weak var tblResults: UITableView!
    @IBOutlet weak var searchTypeControl: UISegmentedControl!
    @IBOutlet weak var imgEmpty: UIImageView!
    @IBOutlet weak var tableLoader: UIActivityIndicatorView!
    
    var imageURLs: [String] = []
    var imageResults: [UIImage] = []
    var isImageSearch = true
    var webResults: [(title: String, description: String, link: String)] = []
    var fullScreenView: UIView?
    var btnSave: UIButton?
    
    @IBAction func searchTypeChanged(_ sender: UISegmentedControl) {
        if searchTypeControl.selectedSegmentIndex == 0 {
            isImageSearch = true
        } else {
            isImageSearch = false
        }
        
        if txtSearch.text!.count > 0 {
            getQuery()
        }
    }
    
    @IBAction func txtSearch(_ sender: UITextField) {
        getQuery()
    }
    
    @IBAction func btnSearch(_ sender: UIButton) {
        getQuery()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageResultsCVCell", for: indexPath) as! ImageResultsCVCell
        cell.btnImageResult.setBackgroundImage(imageResults[indexPath.row], for: .normal)
        cell.layer.cornerRadius = 8
        cell.layer.borderWidth = 1
        cell.layer.borderColor = CGColor(red: 243/256, green: 243/256, blue: 243/256, alpha: 1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return webResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "webResultsTableCell", for: indexPath) as! WebResultsTableCell
        cell.lblTitle.text = webResults[indexPath.row].title
        cell.lblDescription.text = webResults[indexPath.row].description
        cell.link = webResults[indexPath.row].link
        return cell
    }
    
    func getQuery() {
        view.endEditing(true)
        imageURLs.removeAll()
        imageResults.removeAll()
        webResults.removeAll()
        tblResults.reloadData()
        cvImageResults.reloadData()
        imgEmpty.isHidden = true
        tblResults.isHidden = true
        cvImageResults.isHidden = true
        tableLoader.isHidden = false
        tableLoader.startAnimating()
        let query = txtSearch.text!.filter { !" ".contains($0) } //remove whitespace from query
        
        if query.count > 0 {
            if isImageSearch {
                parseHTMLForImages(query: query)
            } else {
                parseHTMLForWeb(query: query)
            }
        }
    }
    
    func parseHTMLForImages(query: String) {
        let url = "https://www.google.com/search?q=" + query + "&tbm=isch"
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async { [unowned self] in
            do {
                let htmlString = try String(contentsOf: URL(string: url)!, encoding: .ascii)
                let doc = try SwiftSoup.parse(htmlString)
                for element in try doc.select("img").array() {
                    try imageURLs.append(element.attr("data-src"))
                }
                group.leave()
            } catch let error {
                print("Error: \(error)")
            }
        }
        group.notify(queue: .main, execute: { [unowned self] in
            downloadImages()
        })
    }
    
    func parseHTMLForWeb(query: String) {
        let url = "https://www.bing.com/search?q=" + query
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async { [unowned self] in
            do {
                let htmlString = try String(contentsOf: URL(string: url)!, encoding: .ascii)
                let doc = try SwiftSoup.parse(htmlString)
                for element in try doc.select("li").array() {
                    if element.hasClass("b_algo") {
                        let innerDoc = try SwiftSoup.parse(element.html())
                        let description = try innerDoc.select("p").first()?.text()
                        webResults.append((title: try innerDoc.select("a").first()!.text(), description: description ?? "Error loading description", link: try innerDoc.select("a").first()!.attr("href")))
                    }
                }
                group.leave()
            } catch let error {
                print("Error: \(error)")
            }
        }
        group.notify(queue: .main, execute: { [unowned self] in
            tblResults.reloadData()
            tableLoader.stopAnimating()
            tblResults.isHidden = false
        })
    }
    
    func downloadImages() {
        for i in 0...imageURLs.count - 1 {
            AF.request(imageURLs[i]).responseData(completionHandler: { [unowned self] response in
                if response.error == nil {
                    if let data = response.data {
                        imageResults.append(UIImage(data: data)!)
                        cvImageResults.reloadData()
                    }
                }
            })
        }
        tableLoader.stopAnimating()
        cvImageResults.isHidden = false
    }
    
    func saveComplete() {
        let alert = UIAlertController(title: "Saved", message: "The photo has been saved to your library", preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: {_ in
            alert.dismiss(animated: true, completion: { })
        })
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func dismissFullScreenImage() {
        fullScreenView!.removeFromSuperview()
        btnSave!.removeFromSuperview()
    }
    
    @objc func viewFullScreenImage(_ notification: NSNotification) {
        let screenSize = UIScreen.main.bounds
        let width = screenSize.width
        let height = screenSize.height
        fullScreenView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        fullScreenView!.backgroundColor = .white
        let fullScreenImage = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        fullScreenImage.image = notification.object as? UIImage
        fullScreenImage.contentMode = .scaleAspectFit
        fullScreenView!.addSubview(fullScreenImage)
        fullScreenView!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissFullScreenImage)))
        btnSave = UIButton(frame: CGRect(x: width - 60, y: 60, width: 40, height: 40))
        btnSave!.setBackgroundImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        btnSave!.addAction(UIAction(handler: { [unowned self] _ in
            UIImageWriteToSavedPhotosAlbum(fullScreenImage.image!, nil, nil, nil)
            saveComplete()
        }), for: .touchUpInside)
        self.view.addSubview(fullScreenView!)
        self.view.addSubview(btnSave!)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let bgView = UIView()
        bgView.backgroundColor = UIColor.white
        tblResults.backgroundView = bgView
        txtSearch.clearButtonMode = .whileEditing
        let clearButton = txtSearch.value(forKey: "clearButton") as! UIButton
        clearButton.setImage(clearButton.imageView?.image?.withRenderingMode(.alwaysTemplate), for: .normal)
        clearButton.tintColor = UIColor.lightGray
        txtSearch.attributedPlaceholder = NSAttributedString(string: "What are you looking for?", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
        NotificationCenter.default.addObserver(self, selector: #selector(viewFullScreenImage), name: Notification.Name("viewFullScreenImage"), object: nil)
    }
}
