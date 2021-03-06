import UIKit

/// CRUD mappings correspond to the RESTful WS standard
struct HttpBackendService: BackendService {

    /// Maps HTTP method to their string representations
    ///
    /// - get: The HTTP GET method
    /// - post: The HTTP POST method
    /// - put: The HTTP PUT method
    /// - delete: The HTTP delete method
    enum HttpMethod: String {
        case post = "POST"
        case get = "GET"
        case put = "PUT"
        case delete = "DELETE"

        var toCrud: CrudType {
            switch self {
            case .post:
                return .create
            case .get:
                return .read
            case .put:
                return .update
            case .delete:
                return .delete
            }
        }
    }

    func create<Req, Res>(_ request: Req, callback: @escaping (Bool, Res?) -> Void) where Req: Request, Res: Response {
        guard let urlRequest = makeJSONRequest(request, method: .post) else {
            callback(false, nil)
            return
        }

        perform(urlRequest: urlRequest, requestLogin: request.getCanRequestLogin(for: .create), callback: callback)
    }

    func read<Req, Res>(_ request: Req, callback: @escaping (Bool, Res?) -> Void) where Req: Request, Res: Response {
        var urlRequest = URLRequest(url: makeURL(request, for: .get))
        urlRequest.httpMethod = HttpMethod.get.rawValue

        perform(urlRequest: urlRequest, requestLogin: request.getCanRequestLogin(for: .read), callback: callback)
    }

    func update<Req, Res>(_ request: Req, callback: @escaping (Bool, Res?) -> Void) where Req: Request, Res: Response {
        guard let urlRequest = makeJSONRequest(request, method: .put) else {
            callback(false, nil)
            return
        }

        perform(urlRequest: urlRequest, requestLogin: request.getCanRequestLogin(for: .update), callback: callback)
    }

    func delete<Req, Res>(_ request: Req, callback: @escaping (Bool, Res?) -> Void) where Req: Request, Res: Response {
        guard let urlRequest = makeJSONRequest(request, method: .delete) else {
            callback(false, nil)
            return
        }

        perform(urlRequest: urlRequest, requestLogin: request.getCanRequestLogin(for: .delete), callback: callback)
    }

    func uploadProfilePicture(imageData: Data, callback: @escaping (Bool, MProfilePicture?) -> Void) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var request = URLRequest(url: Environment.endpoint.appendingPathComponent("upload"))
        request.httpMethod = HttpMethod.post.rawValue

        let boundary = "\(UUID())"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var bodyData = Data()
        bodyData.append((
            "--\(boundary)\r\n" +
            "Content-Disposition: form-data; name=\"file\"; filename=\"profile\"\r\n" +
            "Content-Type: application/octet-stream\r\n\r\n").data(using: .utf8)!)
        bodyData.append(imageData)
        bodyData.append("\r\n--\(boundary)--".data(using: .utf8)!)
        request.httpBody = bodyData

        session.dataTask(with: request) { (data, status, error) in
            guard let http = status as? HTTPURLResponse,
                http.statusCode != 401 else { // Authorization Error
                    DispatchQueue.main.async {
                        (UIApplication.shared.delegate as? AppDelegate)?.showLoginViewController()
                    }
                    callback(false, nil)
                    return
            }

            guard error == nil,
                let data = data,
                let decodedData = try? JSONDecoder().decode(MProfilePicture.self, from: data) else {
                    callback(false, nil)
                    return
            }

            callback(true, decodedData)
        }.resume()
    }
}

// Utility Functions
extension HttpBackendService {
    func makeURL<Req: Request>(_ request: Req, for method: HttpMethod) -> URL {
        var components = URLComponents(url: Environment.endpoint.appendingPathComponent(request.resource),
                                       resolvingAgainstBaseURL: false)!
        let queryItems = request.getParameters(for: method.toCrud).map {
            URLQueryItem(name: $0.key, value: $0.value.description)
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url!
    }

    func makeJSONRequest<Req: Request>(_ request: Req, method: HttpMethod) -> URLRequest? {
        var urlRequest = URLRequest(url: makeURL(request, for: method))
        urlRequest.httpMethod = method.rawValue

        if !request.hasEmptyBody(for: method.toCrud) {
            guard let encodedData = try? JSONEncoder().encode(request) else {
                return nil
            }

            urlRequest.httpBody = encodedData
        } else {
            urlRequest.httpBody = "{}".data(using: .utf8)
        }

        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return urlRequest
    }

    func perform<Res: Response>(urlRequest request: URLRequest,
                                requestLogin login: Bool,
                                callback: @escaping (Bool, Res?) -> Void) {
        #if DEBUG
        print("Requesting: \(request.httpMethod ?? "not found") \(request.url?.absoluteString ?? "not found")")
        #endif

        let newRequest: URLRequest
        if !Environment.liveAuth, let username = Environment.userAuth.username {
            var request = request
            request.addValue(username, forHTTPHeaderField: "AV-User")
            newRequest = request
        } else {
            newRequest = request
        }

        let session = URLSession(configuration: URLSessionConfiguration.default)
        session.dataTask(with: newRequest) { (data, status, error) in
            guard let http = status as? HTTPURLResponse,
                http.statusCode != 401 else { // Authorization Error
                    if login {
                        DispatchQueue.main.async {
                            (UIApplication.shared.delegate as? AppDelegate)?.showLoginViewController()
                        }
                    }
                    callback(false, nil)
                    return
            }

            guard error == nil,
                let data = data,
                let decodedData = try? JSONDecoder().decode(Res.self, from: data) else {
                    callback(false, nil)
                    return
            }

            callback(true, decodedData)
        }.resume()
    }
}
