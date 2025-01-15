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


// The certificates are added as a resource for this package, should you prefer to use your own, you need to specify the appropriate path
//let certPath:std.string = std.string(Bundle.module.path(forResource: "cacert", ofType: ".pem"))

//try! Connection.setCertsPath(certPath)
	
let userId :std.string = "testUsr" //The user's ID, assigned by You
let userPK :std.string = "L1nZyDmrcQKumKd1jx17SfgpMKECNuuikFFHSNy4iV9PjPdPwak6" //The user's Private Key
let solutionID: std.string = "d2de6b79-c4ef-47be-a54b-abe5257438e5" // The Id of your Solution
let bridgeURL: std.string = "http://localhost:9111" // The address of the Platform

// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:) returns a connection object, that is required to initialise other modules
guard var connection = try? Connection.connect(userPrivKey: userPK, solutionId: solutionID, bridgeUrl: bridgeURL)
else {exit(1)}

// InboxApi utilises both Stores and Threads, thus it requires both of them in it's constructor.


// ThreadApi an instances is initialised with a connection, passed as an inout argument
guard var threadApi = try? ThreadApi.create(connection: &connection) else {exit(1)}
guard var storeApi = try? StoreApi.create(connection: &connection) else {exit(1)}
guard let inboxApi = try? InboxApi.create(connection: &connection,
										  threadApi:&threadApi,
										  storeApi:&storeApi) else {exit(1)}

// CryptoApi allows for cryptographic operations
let cryptoApi = CryptoApi.create()

// In this example we assume that you have already created a context
// and added a user (whose private key you used for connection) to it
let contextID: std.string = "7e7d903c-5abf-4b88-9c94-afb5482414b6" // The Id of your Context

var usersWithPublicKeys = privmx.UserWithPubKeyVector()

// then we add the curernt user to the list (in real world it should be list of all participants)
// together with their assigned username, which can be retrieved from the context
// the public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.push_back(UserWithPubKey(userId: userId,
											 pubKey: try! cryptoApi.derivePublicKey(privKey: userPK)))

// next, we use the list of users to create an Inbox named "My Example Thread" in our current context,
// with the current user as the only member and manager
// Note that
// the method also returns the threadId of newly created thread
let privateMeta = Data("My Example Inbox".utf8)
let publicMeta = Data()

guard let newInboxId = try? inboxApi.createInbox(
	contextId: contextID,
	users: usersWithPublicKeys,
	managers: usersWithPublicKeys,
	publicMeta: publicMeta.asBuffer(),
	privateMeta: privateMeta.asBuffer(),
	filesConfig: nil)  else {exit(1)}


// Next we will create an entry in the newly created inbox.
// To do that, we will need a file to send, as well as a message.
let fileToSend = Data(String(repeating: "#", count: 1024).utf8)
let messageToSend = Data("This is an entry sent @ \(Date.now)".utf8)

// First thing we need to do is get a vector of file handles for the Inbox
var fileHandleVector = privmx.InboxFileHandleVector()
guard let fileHandle = try? inboxApi.createFileHandle(publicMeta: privmx.endpoint.core.Buffer(),
													  privateMeta: privmx.endpoint.core.Buffer(),
													  fileSize: Int64(fileToSend.count)) else {exit(1)}
fileHandleVector.push_back(fileHandle)
// Next we can create an entry handle
guard let entryHandle = try? inboxApi.prepareEntry(inboxId: newInboxId,
												   data: messageToSend.asBuffer(),
												   inboxFileHandles: fileHandleVector,
												   userPrivKey: userPK) else {exit(1)}


var buffer = fileToSend
do{
	// with an entry handle we can start sending a file
	while !buffer.isEmpty {
		// For the sake of the example we will send the file in 256 byte chunks, normally the chunks are much bigger
		let chunk = Data(buffer.prefix(256))
		
		try inboxApi.writeToFile(inboxHandle: entryHandle, inboxFileHandle: fileHandle, dataChunk: chunk.asBuffer())
		buffer = buffer.advanced(by: min(256,buffer.count))
	}
}catch let err as PrivMXEndpointError{
	print(err.getCode() ?? 0, err.getMessage(),err.getName(),separator: "\n")
}

do{
	// after sending all of the files the whole entry can be sent.
	try inboxApi.sendEntry(inboxHandle: entryHandle)
}catch let err as PrivMXEndpointError{
	print(err.getCode(),err.getMessage(),err.getName())
}

//now we retrieve the list of entries, which includes the newly sent one.
// this returns an IboxEntryList structure, that contains a C++ vector of Entrires
guard let entryList = try? inboxApi.listEntries(inboxId: newInboxId,
													 pagingQuery: PagingQuery(skip: 0,
																	  limit: 10,
																	  sortOrder: "desc",
																	  lastId: nil
																	 )) else {exit(1)}


// at last, we print out the entries we retrieved, including the newly sent one.
for entry in entryList.readItems{
	print(entry.entryId, entry.data)
}

// at this point there should be only one entry, with a single file
// let's download that file to a buffer

guard let file = entryList.readItems.first?.files.first else {exit(1)}

var downloadedData: Data = Data()




let fileHandleForReading = try inboxApi.openFile(fileId: file.info.fileId)

var chunk = Data()

repeat{
	chunk = try Data(from: inboxApi.readFromFile(fileHandle: fileHandleForReading, length: 512))
	downloadedData.append(chunk)
}while chunk.count == 512

_ = try inboxApi.closeFile(fileHandle: fileHandleForReading)

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
