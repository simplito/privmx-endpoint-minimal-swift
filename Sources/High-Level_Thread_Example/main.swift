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

print("High-Level Thread Example")

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
		modules: [.thread],
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

guard var threadApi = endpoint.threadApi else { exit(3) }

guard
	let threadId = try? threadApi.createThread(
		in: contextID,
		for: usersWithPublicKeys,
		managedBy: usersWithPublicKeys,
		withPublicMeta: publicMeta,
		withPrivateMeta: privateMeta,
		withPolicies: nil)
else { exit(4) }

// Now we list already present messages, as a way of showcasing the difference later on
guard
	let messages = try? threadApi.listMessages(
		from: threadId,
		basedOn: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: .desc))
else { exit(5) }

print("--------")  //separator

for m in messages.readItems {
	print(m, m.id, m.data)
}

// Message can contain arbitrary data, of smaller size
// for teh sake of this example
let messageToSend = Data("test message data, sent @ \(Date.now)".utf8)


guard
	var messageId = try? threadApi.sendMessage(in: threadId,
											   withPublicMeta: Data(),
											   withPrivateMeta: Data(),
											   containing: messageToSend)
else { exit(6) }


guard
	let messages2 = try? threadApi.listMessages(
		from: threadId,
		basedOn: PagingQuery(
			skip: 0,
			limit: 10,
			sortOrder: .desc))
else { exit(7) }

print("--------")  //separator

for m2 in messages2.readItems {
	print(m2, m2.id, m2.data.getString() ?? "[Message was NIL]")
}

print("---- update -----")

let updatedMessage = "Old message was \"\(String(decoding:messageToSend,as:UTF8.self))\", now it's this @ \(Date.now) !"
guard let updatedMessageAsBuffer = updatedMessage.data(using: .utf8) else {exit(1)}

try! threadApi.updateMessage(messageId,
							 replacingData: updatedMessageAsBuffer,
							 replacingPublicMeta: Data(),
							 replacingPrivateMeta: Data())
	
	
//now we retrieve the new list of messages, which includes the newly updated message.
guard let messagesList2 = try? threadApi.listMessages(from: threadId,
													  basedOn: PagingQuery(skip: 0,
																	  limit: 10,
																	  sortOrder: "desc",
																	  lastId: nil
																	 )) else {exit(1)}


// and print out the messages we retrieved
for m in messagesList2.readItems{
	print(m.info.messageId, m.data.getString() ?? "")
}
