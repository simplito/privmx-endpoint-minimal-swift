// PrivMX Endpoint Minimal Swift
// Copyright © 2024 Simplito sp. z o.o.
//
// This file is project demonstrating usage of PrivMX Platform (https://privmx.dev).
// This software is Licensed under the MIT License.
//
// PrivMX Endpoint and PrivMX Bridge are licensed under the PrivMX Free License.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import PrivMXEndpointSwift
import PrivMXEndpointSwiftNative

// The wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)

typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity

print("Low-Level Store Example")

// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
// in a real-world scenario a certificate that will be used by OpenSSL for the connection needs to be provided.
// let certPath :std.string = "/Path/to/the/certificate.file"
// try Connection.setCertsPath(certPath)

// In this example we assume that a context already exists
// and a user (whose private key is used for connection) has been added to it
let userId: std.string = "YourUserIDGoesHere"
let userPK: std.string = "PrivateKeyOfTheUserInWIFFormatGoesHere"
let solutionID: std.string = "TheIdOfYourSolutionGoesHere"
let bridgeURL: std.string = "Address.Of.The.Bridge:GoesHere"
let contextId: std.string = "TheIdOfYourContextGoesHere"

// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:)
// returns a connection object, that is required to initialise other modules
guard
	var connection = try? Connection.connect(
		userPrivKey: userPK, solutionId: solutionID, bridgeUrl: bridgeURL)
else { exit(1) }

// StoreApi is used for creating Stores as well as reading and creating Files within Stores
// We initialise an instance of it with a connection, passed as an inout argument
guard let storeApi = try? StoreApi.create(connection: &connection) else { exit(1) }

// CryptoApi allows for cryptographic operations and does not require a connection to be used.
let cryptoApi = CryptoApi.create()

// To create a new Store, a list of Users with their Public Keys is needed.
// Thus we create one that will be used for both users and managers
// (typically those lists won't be identical)
var usersWithPublicKeys = privmx.UserWithPubKeyVector()

// We add the current user to the list (in real world it should be a list of all participants).
// The public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.push_back(
	UserWithPubKey(
		userId: userId,
		pubKey: try! cryptoApi.derivePublicKey(privKey: userPK)))

guard let privateMeta = "My Example Store".data(using: .utf8) else { exit(2) }
let publicMeta = Data()

// Next, we use the list as both a list of users and a list of managers to create a Store,
// passing "My Example Inbox" as its private metadata.
// The method also returns the storeId of newly created Inbox.
// Passing a nil to filesConfig means the default one will be used.
guard
	let newStoreId = try? storeApi.createStore(
		contextId: contextId,
		users: usersWithPublicKeys,
		managers: usersWithPublicKeys,
		publicMeta: publicMeta.asBuffer(),
		privateMeta: privateMeta.asBuffer())
else { exit(3) }

let fileToSend = Data(String(repeating: "#", count: 1024).utf8)

let writeFileHandle = try storeApi.createFile(
	storeId: newStoreId,
	publicMeta: privmx.endpoint.core.Buffer(),
	privateMeta: privmx.endpoint.core.Buffer(),
	size: 1024)
var buffer = fileToSend
// with an entry handle we can start sending a file
while !buffer.isEmpty {
	// For the sake of the example we will send the file in 256 byte chunks, normally the chunks are much bigger
	let chunk = Data(buffer.prefix(256))

	try storeApi.writeToFile(handle: writeFileHandle, dataChunk: chunk.asBuffer())
	buffer = buffer.advanced(by: min(256, buffer.count))
}

let newFileID = try storeApi.closeFile(handle: writeFileHandle)

// We again list the Files in the store and print them, this time the list contains a new file.
// Note that this does not download the actual files, but only their descriptions.
guard
	let filesList = try? storeApi.listFiles(
		storeId: newStoreId,
		pagingQuery: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: "desc",
			lastId: nil
		))
else { exit(4) }

guard let fileId = filesList.readItems.first?.info.fileId
else { exit(5) }
var downloadedData: Data = Data()

let fileHandle = try storeApi.openFile(fileId: fileId)

var chunk = Data()

repeat {
	chunk = try Data(from: storeApi.readFromFile(handle: fileHandle, length: 512))
	downloadedData.append(chunk)
} while chunk.count == 512

_ = try storeApi.closeFile(handle: fileHandle)

print(downloadedData)

// This is the helper extension for converting Data to privmx.endpoint.core.Buffer and back
extension Data {
	/// Helper, that returns contents of this instance as `privmx.endpoint.core.Buffer`
	/// - Returns: Buffer
	public func asBuffer() -> privmx.endpoint.core.Buffer {
		let pointer = [UInt8](self)
		let dataSize = self.count
		let resultCppString = privmx.endpoint.core.Buffer.from(pointer, dataSize)
		return resultCppString
	}

	public init(from buffer: privmx.endpoint.core.Buffer) throws {
		guard let cDataPtr = buffer.__dataUnsafe() else {
			var err = privmx.InternalError()
			err.name = "Data Error"
			err.message = "Data was nil"
			throw PrivMXEndpointError.otherFailure(err)
		}
		let dataSize = buffer.size()
		self.init(bytes: cDataPtr, count: dataSize)
	}
}
