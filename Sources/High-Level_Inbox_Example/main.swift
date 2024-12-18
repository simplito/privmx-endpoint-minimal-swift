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


import PrivMXEndpointSwiftExtra
import PrivMXEndpointSwift
import PrivMXEndpointSwiftNative
import Foundation

// The wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)

typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey //for brevity
typealias PagingQuery = privmx.endpoint.core.PagingQuery //for brevity

print("High-Level Inbox Example")

// This example assumes that the bridge is hosted locally on your machine, which removes the necessity of setting ssl certificates
// in a real-world scenario you will need to provide a certificate that will be used by OpenSSL for the connection
//let certPath = "/Path/to/the/certificate.file"

// You can set the certs either by calling
//.setCertsPath(_:) on an instance of PrivMXEndpointContainer
// or by calling the method below
//try Connection.setCertsPath(certPath)
let userId = "YourUserIDGoesHere" //The user's ID, assigned by You
let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere" //The user's Private Key
let solutionID = "TheIdOfYourSolutionGoesHere" // The Id of your Solution
let bridgeURL = "Address.Of.The.Bridge/GoesHere" // The address of the Platform Bridge,

// The static method Connection.connect(as:to:on:) returns a connection object, that is required to initialise other modules
guard var endpoint = try? PrivMXEndpoint.init(modules: [.inbox],
											  userPrivKey: userPK,
											  solutionId: solutionID,
											  bridgeUrl: bridgeURL) else {exit(1)}
// In this example we assume that you have already created a context
// and added a user (whose private key you used for connection) to it
// alternatively you can call endpoint.connection.listContexts()
// which will return a list of contexts to which the current user has been added
let contextID = "TheIdOfYourContextGoesHere"


var usersWithPublicKeys = [privmx.endpoint.core.UserWithPubKey]()

// then we add the curernt user to the list (in real world it should be list of all participants)
// together with their assigned username, which can be retrieved from the context
// the public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.append(UserWithPubKey(userId: std.string(userId),
										  pubKey: try! CryptoApi.create().derivePublicKey(privKey: std.string(userPK))))

// next, we use the list of users to create a thread named "My Example Thread" in our current context,
// with the current user as the only member and manager
// the method also returns the threadId of newly created thread
guard let privateMeta = "My Example Inbox".data(using: .utf8) else {exit(2)}
let publicMeta = Data()

guard var inboxApi = endpoint.inboxApi else {exit(3)}

guard let inboxId = try? inboxApi.createInbox(in: contextID,
								   for: usersWithPublicKeys,
								   managedBy: usersWithPublicKeys,
								   withPublicMeta: Data(),
								   withPrivateMeta: Data("A new Inbox".utf8),
								   withFilesConfig: privmx.endpoint.inbox.FilesConfig(minCount: 1,
																					  maxCount: 1,
																					  maxFileSize: 64,
																					  maxWholeUploadSize: 128),
								   withPolicies: nil)
else {
	exit(4)
}

guard var entryHandler = try? InboxEntryHandler.prepareInboxEntryHandler(using: inboxApi,
																   in: inboxId,
																   containing: Data(),
																   sending: [
																	BufferDataSource(buffer: Data("test buffer data".utf8),
																					 privateMeta: Data(),
																					 publicMeta: Data(),
																					 size: 16)
																   ],
																		 as: userPK)
else {
	exit(5)
}

guard .sent == ((try? entryHandler.startSending()) ?? .error)
else {exit(6)}

do{
	try entryHandler.sendEntry()
}catch{
	exit(7)
}

guard let entries = try? inboxApi.listEntries(from: inboxId,
											  basedOn: PagingQuery(skip: 0,
																   limit: 10,
																   sortOrder: .asc))
else {
	exit(8)
}
for e in entries.readItems{
	print(e)
}
	
