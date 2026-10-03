import Foundation

// SDK/UI doubles: execute the production ImageLoader source with controlled callbacks.
protocol ObservableObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
final class UIImage {
    let data: Data
    init?(data: Data) {
        guard data.first == 1 else { return nil }
        self.data = data
    }
}
final class Storage {
    static let instance = Storage()
    static func storage() -> Storage { instance }
    var requests: [(path: String, callback: (Data?, Error?) -> Void)] = []
    func reference(forURL path: String) -> StorageReference { StorageReference(path: path) }
}
struct StorageReference {
    let path: String
    func getData(maxSize: Int64, completion: @escaping (Data?, Error?) -> Void) {
        precondition(maxSize == 5 * 1024 * 1024)
        Storage.instance.requests.append((path, completion))
    }
}
func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.03)) }
func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}

@main struct ImageLoaderTests {
    static func main() {
        let loader = ImageLoader()
        loader.loadImage(from: "part-one.png")
        Storage.instance.requests[0].callback(Data([1, 10]), nil); drain()
        expect(loader.image?.data == Data([1, 10]), "first image loaded")
        loader.loadImage(from: "part-two.png")
        expect(loader.image == nil && loader.error == nil, "switch clears image and error")
        loader.loadImage(from: "part-three.png")
        Storage.instance.requests[2].callback(Data([1, 30]), nil); drain()
        Storage.instance.requests[1].callback(Data([1, 20]), nil); drain()
        expect(loader.image?.data == Data([1, 30]), "late success cannot replace selected part")
        Storage.instance.requests[1].callback(nil, NSError(domain: "late", code: 1)); drain()
        expect(loader.error == nil, "late failure cannot replace selected part")
        loader.loadImage(from: "missing.png")
        Storage.instance.requests[3].callback(nil, NSError(domain: "missing", code: 2)); drain()
        expect(loader.image == nil && loader.error != nil, "failure remains distinct from success")
        loader.loadImage(from: "invalid.png")
        expect(loader.error == nil, "retry clears previous error")
        Storage.instance.requests[4].callback(Data([0]), nil); drain()
        expect(loader.image == nil && loader.error != nil, "invalid data stops loading")
        print("PASS: 4 image-state groups (switch, late callbacks, failure/retry, invalid data)")
    }
}
