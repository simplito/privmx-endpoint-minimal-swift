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
		modules: [.store],
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

guard var storeApi = endpoint.storeApi else { exit(3) }

guard
	let storeId = try? storeApi.createStore(
		in: contextID,
		for: usersWithPublicKeys,
		managedBy: usersWithPublicKeys,
		withPublicMeta: publicMeta,
		withPrivateMeta: privateMeta,
		withPolicies: nil)
else { exit(4) }

// Now we list already present files, as a way of showcasing the difference
guard
	let entries = try? storeApi.listFiles(
		from: storeId,
		basedOn: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: .desc))
else { exit(5) }

print("--------")  //separator

for e in entries.readItems {
	print(e.id, e.size)
}

// An entry can contain no files, but for the sake of this example we'll send one from a buffer
let fileToSend = Data(String(repeating: "#", count: 1024).utf8)

// Next we create the handler for creating and sending the entry
// This also can be done anonymously by passing `nil` instead of the user key.
nonisolated(unsafe) var fileId :String = ""
nonisolated(unsafe) var err = false
nonisolated(unsafe) var threadDone = false //hacky solution to using async function in main

var semaphore1 = DispatchSemaphore(value: 0)
Task.detached(){
	if let fid = try? await endpoint.startUploadingNewFileFromBuffer(fileToSend,
																		to: storeId,
																		withPublicMeta: Data(),
																		withPrivateMeta: Data(),
																		sized: Int64(fileToSend.count),
																	 withChunksOf: 256){
		
			fileId = fid
	} else {
		err = true
	}
	threadDone = true//hacky solution to using async function in main
}
while(!threadDone){} //hacky solution to using async function in main
guard
	let files2 = try? storeApi.listFiles(
		from: storeId,
		basedOn: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: .desc))
else { exit(9) }

print("--------")  //separator

for e in files2.readItems {
	print(e, e.id)
}

nonisolated(unsafe) var downloadedData:Data = Data()
//var semaphore2 = DispatchSemaphore(value: 0)
// There are 2 ways to download provided by the high-level wrapper: using an async PrivMXEndpoint method, or by creating the handler directly
// For the sake of this example, we'll be using the async method and waiting for it to execute
threadDone = false
Task.detached(){
	downloadedData = (try? await endpoint.startDownloadingToBuffer(from: fileId)) ?? Data("Errors Occured".utf8)
	threadDone = true
}
while !threadDone{}//hacky solution to using async function in main

// And finally we print the downloaded data
print(downloadedData)
print(String(downloadedData.rawCppString()))
