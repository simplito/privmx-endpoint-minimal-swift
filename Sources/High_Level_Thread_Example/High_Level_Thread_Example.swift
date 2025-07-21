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

@main
struct High_Level_Thread_Example{
	public static func main() async throws {
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("High-Level Thread Example")
		
		// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
		// in a real-world scenario a certificate that will be used by OpenSSL for the connection needs to be provided.
		// let certPath = "/Path/to/the/certificate.file"
		
		// You can set the certificate either by calling
		// .setCertsPath(_:) on an instance of PrivMXEndpointContainer
		// or by calling
		// try Connection.setCertsPath(certPath)
		
		// In this example we assume that a context already exists
		// and a user (whose private key is used for connection) has been added to it
		let userId = "YourUserIDGoesHere"
		let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere"
		let solutionID = "TheIdOfYourSolutionGoesHere"
		let bridgeURL = "Address.Of.The.Bridge:GoesHere"
		let contextId = "TheIdOfYourContextGoesHere"
		
		// We create an instance of PrivMXEndpoint.
		// In a real-world scenario you'd be using a PrivMXEndpointContainer to manage PrivMXEndpoints as well as handle the event loop,
		// but since we aren't concerned with real time updates or multiple connections in this example,
		// instancing this class directly will suffice.
		guard
			var endpoint = try? PrivMXEndpoint.init(
				modules: [.thread],
				userPrivKey: userPK,
				solutionId: solutionID,
				bridgeUrl: bridgeURL)
		else { exit(1) }
		
		// To create a new Thread, a list of Users with their Public Keys is needed.
		// Thus we create one that will be used for both users and managers
		// (typically those lists won't be identical)
		var usersWithPublicKeys = [privmx.endpoint.core.UserWithPubKey]()
		
		// We add the current user to the list (in real world it should be a list of all participants).
		// The public key in this particular case can be derived from the private key,
		// but in typical circumstance should be acquired from an outside source (like your authorisation server)
		usersWithPublicKeys.append(
			UserWithPubKey(
				userId: std.string(userId),
				pubKey: try! CryptoApi.create().derivePublicKey(privKey: std.string(userPK))))
		
		let publicMeta = Data()
		let privateMeta = Data("My Example Thread".utf8)
		guard var threadApi = endpoint.threadApi
		else { exit(2) }
		
		// Next, we use the list as both a list of users and a list of managers to create a Thread
		// passing "My Example Thread" as its private metadata.
		// The method also returns the threadId of newly created Thread.
		// The nil Policies mean that the default value will be used.
		guard
			let threadId = try? threadApi.createThread(
				in: contextId,
				for: usersWithPublicKeys,
				managedBy: usersWithPublicKeys,
				withPublicMeta: publicMeta,
				withPrivateMeta: privateMeta,
				withPolicies: nil)
		else { exit(4) }
		
		// Now we list already present messages, as a way of showcasing the difference later on,
		// since there will be none, at this point.
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
		
		// Message can contain arbitrary data, but for this example we'll send just text.
		let messageToSend = Data("test message data, sent @ \(Date.now)".utf8)
		
		guard
			var messageId = try? threadApi.sendMessage(
				in: threadId,
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
		
		let updatedMessage =
		"Old message was \"\(String(decoding:messageToSend,as:UTF8.self))\", now it's this @ \(Date.now) !"
		guard let updatedMessageAsBuffer = updatedMessage.data(using: .utf8) else { exit(1) }
		
		try! threadApi.updateMessage(
			messageId,
			replacingData: updatedMessageAsBuffer,
			replacingPublicMeta: Data(),
			replacingPrivateMeta: Data())
		
		//now we retrieve the new list of messages, which includes the newly updated message.
		guard
			let messagesList2 = try? threadApi.listMessages(
				from: threadId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc
				))
		else { exit(1) }
		
		// and print out the messages we retrieved
		for m in messagesList2.readItems {
			print(m.info.messageId, m.data.getString() ?? "")
		}
	}
}
