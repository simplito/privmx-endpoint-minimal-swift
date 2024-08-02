// PrivMX Endpoint Minimal Swift
// Copyright © 2024 Simplito sp. z o.o.
//
// This file is project demonstrating usage of PrivMX Platform (https://privmx.cloud).
// This software is Licensed under the MIT Licence.
//
// See the License for the specific language governing permissions and
// limitations under the License.
//


import PrivMXEndpointSwiftNative
import PrivMXEndpointSwift
import Foundation

// the wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)

typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey //for brevity
typealias ListQuery = privmx.endpoint.core.ListQuery //for brevity


// The certificates are added as a resource for this package, should you prefer to use your own, you need to specify the appropriate path
let certPath:std.string = std.string(Bundle.module.path(forResource: "cacert", ofType: ".pem"))

try CoreApi.setCertsPath(certPath)

let userPK :std.string = "PrivateKeyOfTheUserInWIFFormatGoesHere" //The user's Private Key
let solutionID: std.string = "TheIdOfYourSolutionGoesHere" // The Id of your Solution
let platformUrl: std.string = "Address.Of.The.Platform/GoesHere" // The address of the Platform


// The static method createConnection(userPrivKey:solutionId:PlatformUrl:) returns a connection object, that is required to initialise other modules
var coreApi = try CoreApi(userPrivKey: userPK,
						  solutionId: solutionID,
						  platformUrl: platformUrl)

// ThreadsApi instance is initialised with a connection, passed as an inout argument
// ThreadsApi is used for creating threads as well as reading and creating messages within threads
let threadApi = ThreadApi(coreApi: &coreApi)

// CryptoApi allows for cryptographic operations
let cryptoApi = CryptoApi()

// getting the list of contexts, in this example we assume that you have already created a context
// and added a user (whose private key you used for connection) to it
let ctx = try coreApi.listContexts(query: ListQuery(skip: 0,
													limit: 10,
													sortOrder: "desc",
													lastId: nil
												   )).contexts.first!

var usersWithPublicKeys = privmx.UserWithPubKeyVector()

// then we add the curernt user to the list
// together with their assigned username, which can be retrieved from the context
// the public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.push_back(UserWithPubKey(userId: ctx.userId,
											 pubKey: try! cryptoApi.pubKeyNew(from: userPK)))

// next, we use the list of users to create a thread named "My Example Thread" in our current context,
// with the current user as the only member and manager
// the method also returns the threadId of newly created thread
var newThreadId = try threadApi.createThread("My Example Thread",
											 with: usersWithPublicKeys,
											 managedBy: usersWithPublicKeys,
											 in: ctx.contextId)


// this creates a new message in the specified thread, in this case the newly created one
// the returned string is the messageId of th enewly created message
let res_msg = try threadApi.sendMessage(threadId: newThreadId, // thread in whech the message is sent
										publicMeta: privmx.endpoint.core.Buffer(), // metadata that wont be encrypted, we don't need it for now
										privateMeta: privmx.endpoint.core.Buffer(), // metadata that will be encryopted, we don't need it for now
										data: privmx.endpoint.core.Buffer.from(std.string("Hello World @ \(Date.now) !")))
										
print("New message id: ", String(res_msg)) // the id of newly created message

//now we retrieve the list of messages, which includes the newly sent message.
// this returns a threadMessagesList structure, that contains a vector of threadMessages, as well as the total number of messages in thread
let messages =	try threadApi.listMessages(from: newThreadId,
										   query: ListQuery(skip: 0,
															limit: 10,
															sortOrder: "desc",
															lastId: nil
														   )).messages
// at last, we print out the messages we retrieved, including the newly sent one
for message in messages{
	print(message.info.messageId, message.data)
}
