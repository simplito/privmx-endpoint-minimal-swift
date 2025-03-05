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


import PrivMXEndpointSwiftNative
import PrivMXEndpointSwift
import Foundation

// The wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)

typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey //for brevity
typealias PagingQuery = privmx.endpoint.core.PagingQuery //for brevity

print("Low-Level Inbox Example")

// This example assumes that the bridge is hosted locally on your machine, which removes the necessity of setting ssl certificates
// in a real-world scenario you will need to provide a certificate that will be used by OpenSSL for the connection
//let certPath :std.string = "/Path/to/the/certificate.file"

// You can set the certs by calling
// try Connection.setCertsPath(certPath)

// In this example we assume that a context already exists
// and a user (whose private key is used for connection) has been added to it.
let userId :std.string = "YourUserIDGoesHere"
let userPK :std.string = "PrivateKeyOfTheUserInWIFFormatGoesHere"
let solutionID :std.string = "TheIdOfYourSolutionGoesHere"
let bridgeURL :std.string = "Address.Of.The.Bridge:GoesHere"
let contextId :std.string = "TheIdOfYourContextGoesHere"

// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:) returns a connection object,
// which is required by almost all other Api classes
guard var connection = try? Connection.connect(
	userPrivKey: userPK,
	solutionId: solutionID,
	bridgeUrl: bridgeURL)
else {exit(1)}

// InboxApi utilises both Stores and Threads, thus it requires both of them in it's constructor.
// Each of those are created by passing a Connection as an inout argument to their respective create(connection:) methods.

guard var threadApi = try? ThreadApi.create(
	connection: &connection)
else {exit(2)}
guard var storeApi = try? StoreApi.create(
	connection: &connection)
else {exit(3)}
guard let inboxApi = try? InboxApi.create(
	connection: &connection,
	threadApi:&threadApi,
	storeApi:&storeApi)
else {exit(4)}

// CryptoApi allows for cryptographic operations and does not require a connection to be used.
let cryptoApi = CryptoApi.create()

// To create a new Inbox, a list of Users with their Public Keys is needed.
// Thus we create one that will be used for both users and managers
// (typically those lists won't be identical)

var usersWithPublicKeys = privmx.UserWithPubKeyVector()

// We add the curernt user to the list (in real world it should be a list of all participants).
// The public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.push_back(UserWithPubKey(userId: userId,
											 pubKey: try! cryptoApi.derivePublicKey(privKey: userPK)))

let privateMeta = Data("My Example Inbox".utf8)
let publicMeta = Data()

// Next, we use the list as both a list of users and a list of managers to create an inbox
// passing "My Example Inbox" as its private metadata.
// The method also returns the inboxId of newly created Inbox.
// Passing a nill to filesConfing means the default one will be used.
guard let newInboxId = try? inboxApi.createInbox(
	contextId: contextId,
	users: usersWithPublicKeys,
	managers: usersWithPublicKeys,
	publicMeta: publicMeta.asBuffer(),
	privateMeta: privateMeta.asBuffer(),
	filesConfig: nil)
else {exit(5)}

// Now we list already present entries as a way of showcasing the difference later on,
// since there will be none, at this point.
guard let entries = try? inboxApi.listEntries(
	inboxId: newInboxId,
	pagingQuery: PagingQuery(
		skip: 0,
		limit: 10,
		sortOrder: "desc",
		lastId: nil))
else { exit(6) }

for e in entries.readItems {
	print(e, e.entryId, e.data)
}
print("--------")  //separator

// Next we will create an entry in the newly created inbox.
// To do that, we will need a file to send, as well as a message.
let fileToSend = Data(String(repeating: "#", count: 1024).utf8)
let messageToSend = Data("This is an entry sent @ \(Date.now)".utf8)

// First thing we need to do is get a vector of file handles for the Inbox
var fileHandleVector = privmx.InboxFileHandleVector()
// And populate it with the handles for files that will be uploaded as part of this entry.

guard let fileHandle = try? inboxApi.createFileHandle(
	publicMeta: privmx.endpoint.core.Buffer(),
	privateMeta: privmx.endpoint.core.Buffer(),
	fileSize: Int64(fileToSend.count))
else {exit(7)}

fileHandleVector.push_back(fileHandle)

// Next we can create an entry handle
guard let entryHandle = try? inboxApi.prepareEntry(
	inboxId: newInboxId,
	data: messageToSend.asBuffer(),
	inboxFileHandles: fileHandleVector,
	userPrivKey: userPK)
else {exit(8)}


var buffer = fileToSend
// With an entry handle we can start uploading a File.

do{
	while !buffer.isEmpty {
		// For the sake of the example we will send the file in 256 byte chunks, normally the chunks are much bigger
		let chunk = Data(buffer.prefix(256))
		
		try inboxApi.writeToFile(
			inboxHandle: entryHandle,
			inboxFileHandle: fileHandle,
			dataChunk: chunk.asBuffer())
		buffer = buffer.advanced(by: min(256,buffer.count))
	}
} catch {
	let err = error as? PrivMXEndpointError
	print(err?.getCode() ?? 0,
		  err?.getMessage() ?? "-" ,
		  err?.getName() ?? "-",
		  separator: "\n")
}

do{
	// After sending all of the files the whole entry can be sent.
	try inboxApi.sendEntry(inboxHandle: entryHandle)
}catch let err as PrivMXEndpointError{
	print(err.getCode() as Any,err.getMessage(),err.getName())
}

// Now we retrieve the list of entries, which includes the newly sent one.
// This returns an IboxEntryList structurecontaining a C++ vector of Entrires
guard let entryList = try? inboxApi.listEntries(
	inboxId: newInboxId,
	pagingQuery: PagingQuery(skip:0,
							 limit: 10,
							 sortOrder: "desc",
							 lastId: nil))
else {exit(9)}


// At last, we print out the entries we retrieved, including the newly sent one.
for entry in entryList.readItems{
	print(entry.entryId, entry.data)
}

// At this point there should be only one entry, with a single file
// let's download that file to a buffer and compare it with the data we sent

guard let file = entryList.readItems.first?.files.first else {exit(9)}

var downloadedData: Data = Data()

let fileHandleForReading = try inboxApi.openFile(fileId: file.info.fileId)

var chunk = Data()

repeat{
	chunk = try Data(from: inboxApi.readFromFile(fileHandle: fileHandleForReading, length: 512))
	downloadedData.append(chunk)
}while chunk.count == 512

_ = try inboxApi.closeFile(fileHandle: fileHandleForReading)

print(downloadedData == fileToSend)

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
