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
struct High_Level_Inbox_Example{
	public static func main() async throws{
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("High-Level Inbox Example")
		
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
		
		// We create an instance of PrivMXEndpoint.
		// In a real-world scenario you'd be using a PrivMXEndpointContainer to manage PrivMXEndpoints as well as handle the event loop,
		// but since we aren't concerned with real time updates or multiple connections in this example,
		// instancing this class directly will suffice.
		guard
			var endpoint = try? PrivMXEndpoint.init(
				modules: [.inbox],
				userPrivKey: userPK,
				solutionId: solutionID,
				bridgeUrl: bridgeURL)
		else { exit(1) }
		
		// To create a new Inbox, a list of Users with their Public Keys is needed.
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
		let privateMeta = Data("My Example Inbox".utf8)
		guard var inboxApi = endpoint.inboxApi
		else { exit(2) }
		
		// Next, we use the list as both a list of users and a list of managers to create an inbox
		// passing "My Example Inbox" as its private metadata.
		// The method also returns the inboxId of newly created Inbox.
		// The nills passed for FilesConfig and Policies mean that the default values will be used.
		guard
			let inboxId = try? inboxApi.createInbox(
				in: contextId,
				for: usersWithPublicKeys,
				managedBy: usersWithPublicKeys,
				withPublicMeta: publicMeta,
				withPrivateMeta: privateMeta,
				withFilesConfig: nil,
				withPolicies: nil)
		else { exit(3) }
		
		// Now we list already present entries as a way of showcasing the difference later on,
		// since there will be none, at this point.
		guard
			let entries = try? inboxApi.listEntries(
				from: inboxId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc))
		else { exit(4) }
		
		for e in entries.readItems {
			print(e, e.entryId, e.data)
		}
		print("--------")  //separator
		
		// To create an entry we need to prepare the files to be sent in that entry
		var files = [any FileDataSource]()
		
		// An entry can contain no files, but for the sake of this example we'll send one from a buffer.
		let fileToSend = Data(String(repeating: "#", count: 1024).utf8)
		let messageToSend = Data("This is an entry sent @ \(Date.now)".utf8)
		
		files.append(
			BufferDataSource(
				buffer: fileToSend,
				privateMeta: Data(),
				publicMeta: Data(),
				size: Int64(fileToSend.count)))
		
		// Next we create the handler for creating and sending the entry
		// The "as:" parameter takes in a private key, from which a public key wil be derived
		// to allow for addressing eventual responses to the entry
		guard
			var entryHandler = try? InboxEntryHandler.prepareInboxEntryHandler(
				using: inboxApi,
				in: inboxId,
				containing: messageToSend,
				sending: files,
				derivingPublicKeyFrom: userPK)
		else { exit(5) }
		
		// Now we start the process of sending the files.
		// In a real-world scenario this would happen on a separate thread,
		// but since the data to be sent is miniscule here, we can afford to do this synchronously.
		
		var ehState: InboxEntryHandlerState
		do {
			ehState = try entryHandler.sendFiles()
		} catch let err as PrivMXEndpointError {
			ehState = .error
			print(
				"| ERROR:",
				err.getCode() as Any, err.getMessage(), err.getName(), err.getDescription(),
				separator: "\n|")
		}
		
		// We ensure the files were sent, before we finalize sending the entry.
		guard .filesSent == ehState
		else { exit(6) }
		
		// Once all files are uploaded, the whole Entry can be sent.
		do {
			try entryHandler.sendEntry()
		} catch { exit(7) }
		
		// After that we can list the entries in the Inbox, to see the sent Entry
		guard
			let entries2 = try? inboxApi.listEntries(
				from: inboxId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc))
		else { exit(8) }
		
		print("--------")  //separator
		
		for en in entries2.readItems {
			print(
				en.entryId,
				(try? String(decoding: Data(from: en.data), as: UTF8.self)) ?? "ERROR decoding data")
		}
		
		// Now we'll download one of the files associated with an entry.
		// For that we need an ID of the file to download.
		// We can retrieve it from the entry's list of Files.
		let eid: privmx.endpoint.inbox.InboxEntry? = entries2.readItems.first
		let fileID = eid?.files.first?.id
		
		nonisolated(unsafe) var downloadedData: Data = Data()
		nonisolated(unsafe) var threadDone = false  //hacky solution to using async function in main
		
		// There are 2 ways to download provided by the high-level wrapper: using an async PrivMXEndpoint method,
		// or by creating the handler and using it directly.
		// For the sake of this example, we'll be using the async method and waiting for it to execute
		Task.detached {
			downloadedData = (try await endpoint.startDownloadingToBufferFromInbox(from: fileID!))
			threadDone = true
		}
		while !threadDone {}  //hacky solution to using async function in main
		
		// And finally we print the downloaded data
		print(downloadedData)
		print(downloadedData.asBuffer().getString() ?? "Error decoding data")
	}
}
