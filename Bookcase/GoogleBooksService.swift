import Foundation
import UIKit
import SwiftyJSON

protocol BooksService {
    func getBook(with barcode: String,
                 completionHandler: @escaping (Book?, Error?) -> Void)
    func cancel()
}

class GoogleBooksService: NSObject, BooksService, URLSessionDelegate {
    let googleUrl = "https://www.googleapis.com/books/v1/volumes"
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }()
    
    private func parseSwiftyJSON(data: Data,
                                 completionHandler: @escaping (Book?, Error?) -> Void) {
        let dataAsJSON = try! JSON(data: data)
        if let title = dataAsJSON["items"][0]["volumeInfo"]["title"].string,
           let authors = dataAsJSON["items"][0]["volumeInfo"]["authors"].arrayObject as? [String],
           let thumbnailURL = dataAsJSON["items"][0]["volumeInfo"]["imageLinks"]["thumbnail"].string {
            let book = Book(title: title, author: authors.joined(separator: ","), rating: 0, isbn: "0", notes: "")
            loadCover(book: book, thumbnailURL: thumbnailURL, completionHandler: completionHandler)
//            completionHandler(book, nil)
        } else {
            completionHandler(nil, nil)
        }
    }
    var task: URLSessionDownloadTask?
    func loadCover(book: Book,
                   thumbnailURL: String,
                   completionHandler: @escaping (Book?, Error?) -> Void) {
        var book = book
        guard let url = URL(string: thumbnailURL) else { return }
        task = session.downloadTask(with: url, completionHandler: { temporayURL, response, error in
            if let imageURL = temporayURL,
               let data = try? Data(contentsOf: imageURL),
                let image = UIImage(data: data) {
                book.cover = image
            }
            completionHandler(book, error)
        })
        task?.resume()
    }
    
    private func parseJSON(data: Data, completionHandler: @escaping (Book?, Error?) -> Void) {
        do {
            if let dataAsJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
               let items = dataAsJSON["items"] as? [Any],
               let volume = items[0] as? [String: Any],
               let volumeInfo = volume["volumeInfo"] as? [String: Any],
               let title = volumeInfo["title"] as? String,
               let authors = volumeInfo["authors"] as? [String] {
                let book = Book(title: title, author: authors.joined(separator: ","), rating: 0, isbn: "0", notes: "")
                completionHandler(book, nil)
            } else {
               completionHandler(nil, nil)
            }
        } catch let error as NSError {
            completionHandler(nil, error)
            return
        }
    }
    func getBook(with barcode: String,
                 completionHandler: @escaping (Book?, Error?) -> Void) {
        var components = URLComponents(string: googleUrl)!
        components.queryItems = [
            URLQueryItem(name: "q", value: barcode)
        ]
        
        guard let url = components.url else { return }
        print("url description: ", url.description)
        let request = URLRequest(url: url)
        
        let dataTask = session.dataTask(with: request) { data, response, error in
           // deal with data
            if let error = error {
                completionHandler(nil, error)
                return
            }
            guard let data = data else { return }
//            let dataAsString = String(data: data, encoding: String.Encoding.utf8)
//            self.parseJSON(data: data, completionHandler: completionHandler)
            self.parseSwiftyJSON(data: data, completionHandler: completionHandler)
            // Get book information
        }
        dataTask.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
}
