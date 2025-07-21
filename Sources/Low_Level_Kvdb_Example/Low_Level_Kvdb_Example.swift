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
struct Low_Level_Kvdb_Example{
	public static func main() async throws{
		
		// The wrapper uses Cpp types like std::string (which is imported as std.string or std.__1.string in swift)
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("Low-Level KVDB Example")
		
		// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
		// in a real-world scenario a certificate that will be used by OpenSSL for the connection needs to be provided.
		// let certPath std.string = "/Path/to/the/certificate.file"
		
		// You can set the certificate by calling
		// try Connection.setCertsPath(certPath)
		
		// In this example we assume that a context already exists
		// and a user (whose private key is used for connection) has been added to it
		let userId: std.string = "YourUserIDGoesHere"
		let userPK: std.string = "PrivateKeyOfTheUserInWIFFormatGoesHere"
		let solutionID: std.string = "TheIdOfYourSolutionGoesHere"
		let bridgeURL: std.string = "Address.Of.The.Bridge:GoesHere"
		let contextId: std.string = "TheIdOfYourContextGoesHere"
		
		// The static method Connection.connect(userPrivKey:solutionId:bridgeUrl:) returns a connection object, that is required to initialise other modules
		guard
			var connection = try? Connection.connect(
				userPrivKey: userPK, solutionId: solutionID, bridgeUrl: bridgeURL)
		else { exit(1) }
		
		// KvdbApi instance is initialised with a connection, passed as an inout argument
		// KvdbApi is used for creating kvdbs as well as reading and creating entries within kvdbs
		guard let kvdbApi = try? KvdbApi.create(connection: &connection) else { exit(1) }
		
		// CryptoApi allows for cryptographic operations
		let cryptoApi = CryptoApi.create()
		
		var usersWithPublicKeys = privmx.UserWithPubKeyVector()
		
		// then we add the current user to the list (in real world it should be list of all participants)
		// together with their assigned username, which can be retrieved from the context
		// the public key in this particular case can be derived from the private key,
		// but in typical circumstance should be acquired from an outside source (like your authorisation server)
		usersWithPublicKeys.push_back(
			UserWithPubKey(
				userId: userId,
				pubKey: try! cryptoApi.derivePublicKey(privKey: userPK)))
		
		// next, we use the list of users to create a kvdb named "My Example KVDB" in our current context,
		// with the current user as the only member and manager
		// the method also returns the kvdbId of newly created kvdb
		guard let privateMeta = "My Example KVDB".data(using: .utf8) else { exit(1) }
		let publicMeta = Data()
		
		guard
			let newKvdbId = try? kvdbApi.createKvdb(
				contextId: contextId,
				users: usersWithPublicKeys,
				managers: usersWithPublicKeys,
				publicMeta: publicMeta.asBuffer(),
				privateMeta: privateMeta.asBuffer())
		else { exit(1) }
		
		let entryToSend = "Hello World @ \(Date.now) !"
		guard let entryAsBuffer = entryToSend.data(using: .utf8)?.asBuffer() else { exit(1) }
		
		// Entries are created for a particular pair of KVDB and key, where key acts as an identifier within that Kvdb.
		let entryKey :std.string = "example"
		
		// this creates a new entry in the specified kvdb, in this case the newly created one
		try kvdbApi.setEntry(
			kvdbId: newKvdbId,
			key: entryKey,
			publicMeta: privmx.endpoint.core.Buffer(),
			privateMeta: privmx.endpoint.core.Buffer(),
			data: entryAsBuffer)
		
		//now we retrieve the list of entries, which includes the newly set entry.
		// this returns a kvdbEntriesList object, that contains a vector of kvdbEntries, as well as the total number of entries in the kvdb
		guard
			let entriesList = try? kvdbApi.listEntries(
				kvdbId: newKvdbId,
				pagingQuery: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: "desc",
					lastId: nil,
					sortBy: nil,
					queryAsJson: nil
				))
		else { exit(1) }
		
		// at last, we print out the entries we retrieved, including the new one
		for entry in entriesList.readItems {
			print(entry.info.key, entry.data.getString() ?? "")
		}
		
		print("---- update -----")
		
		let updatedEntry = "Old entry was \"\(entryToSend)\", now it's this @ \(Date.now) !"
		guard let updatedEntryAsBuffer = updatedEntry.data(using: .utf8)?.asBuffer() else { exit(1) }
		
		try! kvdbApi.setEntry(
			kvdbId: newKvdbId,
			key:entryKey,
			publicMeta: privmx.endpoint.core.Buffer(),
			privateMeta: privmx.endpoint.core.Buffer(),
			data: updatedEntryAsBuffer,
			version: 1)
		
		//now we retrieve the new list of entries, which includes the newly updated entry.
		guard
			let entriesList2 = try? kvdbApi.listEntries(
				kvdbId: newKvdbId,
				pagingQuery: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: "desc",
					lastId: nil,
					sortBy: nil,
					queryAsJson: nil
				))
		else { exit(1) }
		
		// and print out the entries we retrieved
		for m in entriesList2.readItems {
			print(m.info.key, m.data.getString() ?? "")
		}
	}
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
		
extension privmx.endpoint.core.Buffer {
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
