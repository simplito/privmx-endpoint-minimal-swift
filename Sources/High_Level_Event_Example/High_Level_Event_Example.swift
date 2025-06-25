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
struct High_Level_Event_Example{
	public static func main() async{
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("High-Level Event Example")
		
		// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
		// in a real-world scenario a certificate that will be used by OpenSSL for the connection needs to be provided.
		// let certPath = "/Path/to/the/certificate.file"
		
		// You can set the certificate either by calling
		// .setCertsPath(_:) on an instance of PrivMXEndpointContainer
		// or by calling `try Connection.setCertsPath(certPath)`
		
		// In this example we assume that a context already exists
		// and a user (whose private key is used for connection) has been added to it
		let userId = "YourUserIDGoesHere"
		let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere"
		let solutionID = "TheIdOfYourSolutionGoesHere"
		let bridgeURL = "Address.Of.The.Bridge:GoesHere"
		
		let contextId = "TheIdOfYourContextGoesHere"
		
		// We create an instance of PrivMXEndpoint with the use of EndpointContainer.
		// This class handles event loop and multiple connections
		let endpointContainer = PrivMXEndpointContainer()
		
		guard let endpoint = try? await endpointContainer.newEndpoint(
			enabling: [.event],
			connectingAs: userPK,
			to: solutionID,
			on: bridgeURL), let eventApi = endpoint.eventApi
		else {exit(1)}
		
		// To emit a CustomEvent, a list of Users with their Public Keys is needed.
		// Thus we create one.
		var usersWithPublicKeys = [privmx.endpoint.core.UserWithPubKey]()
		
		// Recipients unregistered for specific events will not receive notifications about them.
		// Threfore we need to register for this event.
		try? endpoint.registerCallback(
			for: privmx.endpoint.event.ContextCustomEvent.self,
			from: .custom(contextId: contextId, name: "CHANNEL_NAME"),
			identified: ""){
				data in
				if let data = data as? privmx.endpoint.event.ContextCustomEventData {
					print((try? data.payload.toHex()) ?? "?")
				}
			}
		
		// And now we start the event loop.
		 try? await endpointContainer.startListening()
		
		// We add the current user to the list (in real world it should be a list of all users that are supposed to receive the event).
		// The public key in this particular case can be derived from the private key,
		// but in typical circumstance should be acquired from an outside source (like your authorisation server)
		usersWithPublicKeys.append(
			UserWithPubKey(
				userId: std.string(userId),
				pubKey: try! CryptoApi.create().derivePublicKey(privKey: std.string(userPK))))
		
		
		let payload = Data("My Example Event".utf8)
		
		try? eventApi.emitEvent(
			in: contextId,
			to: usersWithPublicKeys,
			on: "CHANNEL_NAME",
			containing: payload)
		
		try? await endpointContainer.stopListening()
	}
}
