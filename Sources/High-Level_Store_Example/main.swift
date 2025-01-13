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
import PrivMXEndpointSwiftExtra
import PrivMXEndpointSwiftNative

typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity

print("High-Level Store Example")

// This example assumes that the bridge is hosted locally on your machine, which removes the necessity of setting ssl certificates
// in a real-world scenario you will need to provide a certificate that will be used by OpenSSL for the connection
//let certPath = "/Path/to/the/certificate.file"

// You can set the certs either by calling
//.setCertsPath(_:) on an instance of PrivMXEndpointContainer
// or by calling the method below
//try Connection.setCertsPath(certPath)

let userId = "YourUserIDGoesHere"  //The user's ID, assigned by You
let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere"  //The user's Private Key
let solutionID = "TheIdOfYourSolutionGoesHere"  // The Id of your Solution
let bridgeURL = "Address.Of.The.Bridge/GoesHere"  // The address of the Platform Bridge,

// We create an PrivMXEndpoint instance, in real-world scenrio you'd be using a PrivMXEndpointContainer to manage PrivMXEndpoints
// as well as handle the event loop. For this example instancing this class directly will suffice.
guard
	var endpoint = try? PrivMXEndpoint.init(
		modules: [.inbox],
		userPrivKey: userPK,
		solutionId: solutionID,
		bridgeUrl: bridgeURL)
else { exit(1) }

// In this example we assume that you have already created a context
// and added a user (whose private key you used for connection) to it
// alternatively you can call endpoint.connection.listContexts()
// which will return a list of contexts to which the current user has been added
let contextID = "TheIdOfYourContextGoesHere"

var usersWithPublicKeys = [privmx.endpoint.core.UserWithPubKey]()

// then we add the curernt user to the list (in real world it should be a list of all participants)
// together with their assigned username, which can be retrieved from the context using PrivMX Bridge REST API
// the public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.append(
	UserWithPubKey(
		userId: std.string(userId),
		pubKey: try! CryptoApi.create().derivePublicKey(privKey: std.string(userPK))))

// next, we use the list of users to create an inbox named "A new Inbox" in our current context,
// with the current user as the only member and manager
// the method also returns the inboxId of newly created Inbox
guard let privateMeta = "My Example Inbox".data(using: .utf8)
else { exit(2) }

let publicMeta = Data()

guard var inboxApi = endpoint.inboxApi else { exit(3) }

guard
	let inboxId = try? inboxApi.createInbox(
		in: contextID,
		for: usersWithPublicKeys,
		managedBy: usersWithPublicKeys,
		withPublicMeta: publicMeta,
		withPrivateMeta: privateMeta,
		withFilesConfig: privmx.endpoint.inbox.FilesConfig(
			minCount: 1,
			maxCount: 1,
			maxFileSize: 64,
			maxWholeUploadSize: 128),
		withPolicies: nil)
else { exit(4) }

// To create an entry we need to prepare the files to be sent in that entry
var files = [any FileDataSource]()

// Now we list already present entries, as a way of showcasing the difference
guard
	let entries = try? inboxApi.listEntries(
		from: inboxId,
		basedOn: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: .desc))
else { exit(5) }

print("--------")  //separator

for e in entries.readItems {
	print(e, e.entryId, e.data)
}

// An entry can contain no files, but for the sake of this example we'll send one from a buffer
let fileToSend = Data("test buffer data".utf8)

// Alternatively we could use a `FileHandleDataSource` instance that uses a file from the disk
// insetad
files.append(
	BufferDataSource(
		buffer: fileToSend,
		privateMeta: Data(),
		publicMeta: Data(),
		size: Int64(fileToSend.count)))

// Next we create the handler for creating and sending the entry
// This also can be done anonymously by passing `nil` instead of the user key.
guard
	var entryHandler = try? InboxEntryHandler.prepareInboxEntryHandler(
		using: inboxApi,  // instance of PrivMXInbox
		in: inboxId,  // id of the Inbox to which the Entry will be sent
		containing: Data("This is an entry".utf8),  // Data sent in the entry
		sending: files,  // List of files to send
		as: userPK)  // as who will the inbox entry be created
else { exit(6) }

// Now we start the process of sending the files
// in a real-world scenarion this would happen on a separate thread,
// but since the data to be sent is miniscule here, we can afford to do this synchronously.
guard .sent == ((try? entryHandler.sendFiles()) ?? .error)
else { exit(7) }

// Once all files are uploaded, the whole Entry can be sent.
do {
	try entryHandler.sendEntry()
} catch { exit(8) }

guard
	let entries2 = try? inboxApi.listEntries(
		from: inboxId,
		basedOn: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: .desc))
else { exit(9) }

print("--------")  //separator

for e in entries2.readItems {
	print(e, e.entryId, e.data)
}

// Now let us download one of the files associated with an entry.
// For that we will need an ID of the file to download
let eid :privmx.endpoint.inbox.InboxEntry? = entries2.readItems.first
let fileID = eid?.files.first?.id


var downloadedData:Data = Data()

// There are 2 ways to download provided by the high-level wrapper: using an async PrivMXEndpoint method, or by creating the handler directly
// For the sake of this example, we'll be using the async method and waiting for it to execute
var semaphore = DispatchSemaphore(value: 0)
Task{
	downloadedData = (try? await endpoint.startDownloadingToBuffer(from: fileID!)) ?? Data("Errors Occured".utf8)
	semaphore.signal()
}
semaphore.wait()

// And finally we print the downloaded data
print(downloadedData)
print(String(downloadedData.rawCppString()))
