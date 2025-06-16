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
struct High_Level_Store_Example{
	public static func main() async throws{
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("High-Level Store Example")
		
		// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
		// in a real-world scenario a certificate, that will be used by OpenSSL for the connection, needs to be provided.
		// let certPath = "/Path/to/the/certificate.file"
		
		// You can set the certificate either by calling
		// .setCertsPath(_:) on an instance of PrivMXEndpointContainer
		// or by calling
		// try Connection.setCertsPath(certPath)
		
		// In this example we assume that you have already created a context
		// and added a user (whose private key you used for connection) to it
		let userId = "YourUserIDGoesHere"
		let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere"
		let solutionID = "TheIdOfYourSolutionGoesHere"
		let bridgeURL = "Address.Of.The.Bridge:GoesHere"
		let contextId = "TheIdOfYourContextGoesHere"
		
		// We create an instance of PrivMXEndpoint,
		// in real-world scenario you'd be using a PrivMXEndpointContainer to manage PrivMXEndpoints as well as handle the event loop.
		// For this example instancing this class directly will suffice.
		guard
			var endpoint = try? PrivMXEndpoint.init(
				modules: [.store],
				userPrivKey: userPK,
				solutionId: solutionID,
				bridgeUrl: bridgeURL)
		else { exit(1) }
		
		// To create a new Store, a list of Users with their Public Keys is needed.
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
		let privateMeta = Data("My Example Store".utf8)
		guard var storeApi = endpoint.storeApi
		else { exit(2) }
		
		// Next, we use the list as both a list of users and a list of managers to create a Store,
		// passing "My Example Store" as its private metadata, treating it as a name
		// the method also returns the storeId of the newly created Store
		guard let storeId = try? storeApi.createStore(
			in: contextId,
			for: usersWithPublicKeys,
			managedBy: usersWithPublicKeys,
			withPublicMeta: publicMeta,
			withPrivateMeta: privateMeta,
			withPolicies: nil)
		else { exit(3) }
		
		// Now we list already present files, as a way of showcasing the difference,
		// As this is a newly created Store, there obviously be no files yet
		guard let entries = try? storeApi.listFiles(
			from: storeId,
			basedOn: PagingQuery(
				skip: 0,
				limit: 10,
				sortOrder: .desc))
		else { exit(5) }
		
		for e in entries.readItems {
			print(e.id, e.size)
		}
		
		print("--------")  //separator for better output readability
		
		let fileToSend = Data(String(repeating: "#", count: 1024).utf8)
		
		nonisolated(unsafe) var fileId: String = ""
		nonisolated(unsafe) var err = false
		nonisolated(unsafe) var threadDone = false  //hacky solution to using async function in main
		
		// The high-level wrapper offers two ways to send and download files:
		// using the PrivMXStoreFileHandler class or using the async methods provided by the PrivMXEndpoint
		// in this example we will be using the latter
		if let fid = try? await endpoint.startUploadingNewFileFromBuffer(
			fileToSend,
			to: storeId,
			withPublicMeta: Data(),
			withPrivateMeta: Data(),
			sized: Int64(fileToSend.count),
			withChunksOf: 256
		) {
			fileId = fid
		} else {
			err = true
		}
		
		// We again list the Files in the store and print them, this time the list contains a new file.
		// Note that this does not download the actual files, but only their descriptions.
		guard
			let files2 = try? storeApi.listFiles(
				from: storeId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc))
		else { exit(9) }
		
		for e in files2.readItems {
			print(e, e.id)
		}
		
		print("--------")  //separator for better output readability
		
		nonisolated(unsafe) var downloadedData: Data = Data()
		
		// There are 2 ways to download provided by the high-level wrapper: using an async PrivMXEndpoint method, or by creating the handler directly
		// For the sake of this example, we'll be using the async method and waiting for it to execute
		threadDone = false
		Task.detached {
			downloadedData =
			(try? await endpoint.startDownloadingToBuffer(from: fileId)) ?? Data("Errors Occurred".utf8)
			threadDone = true
		}
		while !threadDone {}  //hacky solution to using async function in main
		
		// And finally we print the downloaded data
		print(downloadedData)
		print(downloadedData.asBuffer().getString() ?? "ERROR converting to string")
	}
}
