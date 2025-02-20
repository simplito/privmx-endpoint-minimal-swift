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

print("Low-Level Thread Example")

// This example assumes that the bridge is hosted locally on your machine, which removes the necessity of setting ssl certificates
// in a real-world scenario you will need to provide a certificate that will be used by OpenSSL for the connection
//let certPath std.string = "/Path/to/the/certificate.file"

// You can set the certs by calling
// try Connection.setCertsPath(certPath)

// In this example we assume that you have already created a context
// and added a user (whose private key you used for connection) to it
let userId :std.string = "YourUserIDGoesHere"  //The user's ID, assigned by You
let userPK :std.string = "PrivateKeyOfTheUserInWIFFormatGoesHere"  //The user's Private Key
let solutionID :std.string = "TheIdOfYourSolutionGoesHere"  // The Id of your Solution
let bridgeURL :std.string = "Address.Of.The.Bridge:GoesHere"  // The address of the Platform Bridge,
let contextId :std.string = "TheIdOfYourContextGoesHere"
// Optionally you can call endpoint.connection.listContexts()
// that will return a list of contexts to which the current user has been added


// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:) returns a connection object, that is required to initialise other modules
guard var connection = try? Connection.connect(userPrivKey: userPK, solutionId: solutionID, bridgeUrl: bridgeURL)
else {exit(1)}


// ThreadApi instance is initialised with a connection, passed as an inout argument
// ThreadApi is used for creating threads as well as reading and creating messages within threads
guard let threadApi = try? ThreadApi.create(connection: &connection) else {exit(1)}

// CryptoApi allows for cryptographic operations
let cryptoApi = CryptoApi.create()

var usersWithPublicKeys = privmx.UserWithPubKeyVector()

// then we add the curernt user to the list (in real world it should be list of all participants)
// together with their assigned username, which can be retrieved from the context
// the public key in this particular case can be derived from the private key,
// but in typical circumstance should be acquired from an outside source (like your authorisation server)
usersWithPublicKeys.push_back(UserWithPubKey(userId: userId,
											 pubKey: try! cryptoApi.derivePublicKey(privKey: userPK)))

// next, we use the list of users to create a thread named "My Example Thread" in our current context,
// with the current user as the only member and manager
// the method also returns the threadId of newly created thread
guard let privateMeta = "My Example Thread".data(using: .utf8) else {exit(1)}
let publicMeta = Data()

guard let newThreadId = try? threadApi.createThread(
	contextId: contextId,
	users: usersWithPublicKeys,
	managers: usersWithPublicKeys,
	publicMeta: publicMeta.asBuffer(),
	privateMeta: privateMeta.asBuffer())  else {exit(1)}


let messageToSend = "Hello World @ \(Date.now) !"
guard let messageAsBuffer = messageToSend.data(using: .utf8)?.asBuffer() else {exit(1)}

// this creates a new message in the specified thread, in this case the newly created one
// the returned string is the messageId of th enewly created message
let newMessageId = try! threadApi.sendMessage(threadId: newThreadId, // thread in whech the message is sent
											 publicMeta: privmx.endpoint.core.Buffer(), // metadata that wont be encrypted, we don't need it for now
											 privateMeta: privmx.endpoint.core.Buffer(), // metadata that will be encryopted, we don't need it for now
											 data: messageAsBuffer)

print("New message id: ", String(newMessageId)) // the id of newly created message

//now we retrieve the list of messages, which includes the newly sent message.
// this returns a threadMessagesList structure, that contains a vector of threadMessages, as well as the total number of messages in thread
guard let messagesList = try? threadApi.listMessages(threadId: newThreadId,
													 pagingQuery: PagingQuery(skip: 0,
																	  limit: 10,
																	  sortOrder: "desc",
																	  lastId: nil
																	 )) else {exit(1)}


// at last, we print out the messages we retrieved, including the newly sent one
for message in messagesList.readItems{
	print(message.info.messageId, message.data.getString() ?? "")
}

print("---- update -----")

let updatedMessage = "Old message was \"\(messageToSend)\", now it's this @ \(Date.now) !"
guard let updatedMessageAsBuffer = updatedMessage.data(using: .utf8)?.asBuffer() else {exit(1)}

try! threadApi.updateMessage(messageId: newMessageId,
							 publicMeta: privmx.endpoint.core.Buffer(),
							 privateMeta: privmx.endpoint.core.Buffer(),
							 data: updatedMessageAsBuffer)
	
	
//now we retrieve the new list of messages, which includes the newly updated message.
guard let messagesList2 = try? threadApi.listMessages(threadId: newThreadId,
													 pagingQuery: PagingQuery(skip: 0,
																	  limit: 10,
																	  sortOrder: "desc",
																	  lastId: nil
																	 )) else {exit(1)}


// and print out the messages we retrieved
for m in messagesList2.readItems{
	print(m.info.messageId, m.data.getString() ?? "")
}

// This is the helper extension for converting Data to privmx.endpoint.core.Buffer
extension Data {
	/// Helper, that returns contents of this instance as `privmx.endpoint.core.Buffer`
	/// - Returns: Buffer
	public func asBuffer() -> privmx.endpoint.core.Buffer {
		let pointer = [UInt8](self)
		let dataSize = self.count
		let resultCppString = privmx.endpoint.core.Buffer.from(pointer, dataSize)
		return resultCppString
	}
}

extension privmx.endpoint.core.Buffer{
	/// Creates a new `String` instance from the buffer's underlying bytes.
	///
	/// This helper function converts the buffer into a UTF-8 `String`.
	/// - Returns: A new `String` instance if the conversion is successful, otherwise `nil`.
	public func getString() -> String? {
		var data = Data()
		if let bufstr = self.__dataUnsafe() {
			data = Data(bytes: bufstr, count: self.size())
		}
		return String(data: data, encoding: .utf8)
	}
}
