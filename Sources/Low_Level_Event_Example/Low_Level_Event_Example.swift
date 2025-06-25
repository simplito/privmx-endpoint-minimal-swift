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
import PrivMXEndpointSwiftNative

@main
struct Low_Level_Event_Example{
	public static func main() async throws {
		
		// The wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("Low-Level Store Example")
		
		// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
		// in a real-world scenario a certificate that will be used by OpenSSL for the connection needs to be provided.
		// let certPath :std.string = "/Path/to/the/certificate.file"
		// try Connection.setCertsPath(certPath)
		
		// In this example we assume that a context already exists
		// and a user (whose private key is used for connection) has been added to it
		let userId: std.string = "YourUserIDGoesHere"
		let userPK: std.string = "PrivateKeyOfTheUserInWIFFormatGoesHere"
		let solutionID: std.string = "TheIdOfYourSolutionGoesHere"
		let bridgeURL: std.string = "Address.Of.The.Bridge:GoesHere"
		let contextId: std.string = "TheIdOfYourContextGoesHere"
		
		// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:)
		// returns a connection object, that is required to initialise other modules
		guard
			var connection = try? Connection.connect(
				userPrivKey: userPK, solutionId: solutionID, bridgeUrl: bridgeURL)
		else { exit(1) }
		
		// EventApi is used for emitting and handling CustomEvents.
		// We initialise an instance of it with a connection, passed as an inout argument
		guard let eventApi = try? EventApi.create(connection: &connection) else { exit(1) }
		
		
		
		// CryptoApi allows for cryptographic operations and does not require a connection to be used.
		let cryptoApi = CryptoApi.create()
		
		// Recipients unregistered for specific events will not receive notifications about them.
		// Threfore we need to register for this event.
		try eventApi.subscribeForCustomEvents(contextId: contextId, channelName: "CHANNEL_NAME")
		
		// To emit a CustomEvent, a list of Users with their Public Keys is needed.
		// Thus we create one.
		var usersWithPublicKeys = privmx.UserWithPubKeyVector()
		
		// We add the current user to the list (in real world it should be a list of all participants).
		// The public key in this particular case can be derived from the private key,
		// but in typical circumstance should be acquired from an outside source (like your authorisation server)
		usersWithPublicKeys.push_back(
			UserWithPubKey(
				userId: userId,
				pubKey: try! cryptoApi.derivePublicKey(privKey: userPK)))
		
		guard let payload = "My Custom Event".data(using: .utf8) else { exit(2) }

		try eventApi.emitEvent(
			contextId: contextId,
			users: usersWithPublicKeys,
			channelName: "CHANNEL_NAME",
			eventData: payload.asBuffer())
		
		// Since the event has been emitted and we registered for custom events from this combination of contextId and channelName
		// we now can now retrieve it and handle it appropriately.
		// To do so, we get an instance of EventQueue.
		guard let eventQueue = try? EventQueue.getInstance() else {exit(3)}
		
		// Since getEvent retrieves the first event in the queue (or nothig should the queue be empty at the time)
		// we call it here in a while loop, to handle any previous events (like the ones that arrive upon connecting)
		while let eventHolder = try eventQueue.getEvent(){
			// The queue is shared between all connections, so normally you'd have to handle that yourself,
			// for this example there's only one connection however, so we skip that step. We would do that by checking the connectionId in the eventHolder.
			
			// Next we check if the eventHolder contains a CustomEvent.
			if try EventHandler.isContextCustomEvent(eventHolder: eventHolder){
				// If it does, we extract it, and can finally handle it appropriately.
				let event = try EventHandler.extractContextCustomEvent(eventHolder: eventHolder)
				
				// For this example we'll settle for simply printing out the payload.
				print(String(decoding: try Data(from:event.data.payload), as: UTF8.self))
				
			}
			
		}
		
	}
}
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
	
