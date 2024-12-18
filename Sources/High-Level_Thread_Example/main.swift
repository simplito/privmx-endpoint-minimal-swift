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
import PrivMXEndpointSwiftExtra
import Foundation

// The wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)

typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey //for brevity
typealias PagingQuery = privmx.endpoint.core.PagingQuery //for brevity

func main(){
	// The certificates are added as a resource for this package, should you prefer to use your own, you need to specify the appropriate path
	//let certPath:std.string = std.string(Bundle.module.path(forResource: "cacert", ofType: ".pem"))
	
	//try! Connection.setCertsPath(certPath)
	
	let userId = "YourUserIDGoesHere" //The user's ID, assigned by You
	let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere" //The user's Private Key
	let solutionID = "TheIdOfYourSolutionGoesHere" // The Id of your Solution
	let bridgeURL = "Address.Of.The.Bridge/GoesHere" // The address of the Platform
	
	// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:) returns a connection object, that is required to initialise other modules
	guard var connection = try? Connection.connect(as: userPK, to: solutionID, on: bridgeURL) as? Connection
	else {exit(1)}
	
	
	// ThreadApi instance is initialised with a connection, passed as an inout argument
	// ThreadApi is used for creating threads as well as reading and creating messages within threads
	guard let threadApi = try? ThreadApi.create(connection: &connection) else {exit(2)}
	
	// CryptoApi allows for cryptographic operations
	let cryptoApi = CryptoApi.create()
	
	// In this example we assume that you have already created a context
	// and added a user (whose private key you used for connection) to it
	let contextID = "TheIdOfYourContextGoesHere" // The Id of your Context
	
	var usersWithPublicKeys = [UserWithPubKey]()
	
	// then we add the curernt user to the list (in real world it should be list of all participants)
	// together with their assigned username, which can be retrieved from the context
	// the public key in this particular case can be derived from the private key,
	// but in typical circumstance should be acquired from an outside source (like your authorisation server)
	usersWithPublicKeys.append(UserWithPubKey(userId: userId,
												 pubKey: try! cryptoApi.derivePublicKey(from: userPK)))
	
	// next, we use the list of users to create a thread named "My Example Thread" in our current context,
	// with the current user as the only member and manager
	// the method also returns the threadId of newly created thread
	guard let privateMeta = "My Example Thread".data(using: .utf8) else {exit(3)}
	let publicMeta = Data()
	
	guard let newThreadId = try? threadApi.createThread(
		in: contextID,
		for: usersWithPublicKeys,
		managedBy: usersWithPublicKeys,
		withPublicMeta: publicMeta,
		withPrivateMeta: privateMeta)  else {exit(4)}
	
	
	let messageToSend = Data("Hello World @ \(Date.now) !".utf8)
	
	// this creates a new message in the specified thread, in this case the newly created one
	// the returned string is the messageId of th enewly created message
	let newMessageId = try! threadApi.sendMessage(in: newThreadId, // thread in whech the message is sent
												 withPublicMeta: Data(),// metadata that wont be encrypted, we don't need it for now
												 withPrivateMeta: Data(), // metadata that will be encryopted, we don't need it for now
												  containing: messageToSend)
	
	print("New message id: ", String(newMessageId)) // the id of newly created message
	
	//now we retrieve the list of messages, which includes the newly sent message.
	// this returns a threadMessagesList structure, that contains a vector of threadMessages, as well as the total number of messages in thread
	guard let messagesList = try? threadApi.listMessages(from: newThreadId,
														 basedOn: PagingQuery(skip: 0,
																		  limit: 10,
																		  sortOrder: "desc",
																		  lastId: nil
																		 )) else {exit(1)}
	
	
	// at last, we print out the messages we retrieved, including the newly sent one
	for message in messagesList.readItems{
		print(message.info.messageId, message.data)
	}
}
