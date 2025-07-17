
import jimjam.Jimjam;
import sys.FileSystem;

typedef User = {
	> Document,
	name: String,
	email: String,
	age: Int,
	active: Bool,
	?city: String,
	?status: String
}

class Test {
    static var testDb: Jimjam;
    static var testPassed: Int = 0;
    static var testTotal: Int = 0;
    static var currentTest: String = "";

    static function main() {
		Sys.println("\n\033[1m- Jimjam Database Test Suite -\033[0m");

        // Clean up any existing test database
        if (FileSystem.exists("test.db")) {
            FileSystem.deleteFile("test.db");
        }

        // Initialize test database
        testDb = new Jimjam("test.db");

        try {
            // Run all test suites
            testBasicOperations();
            testQueryOperators();
            testTransactions();
            testTypeSystem();
            testSchemaEvolution();
            testIndexManagement();
            testEdgeCases();
            testErrorHandling();
            testIndexOrderIndependence();
            testDataPersistence();

            // Print final results
            printResults();

        } catch (e: Dynamic) {
            Sys.println("FATAL TEST ERROR: " + e);
        }

        // Clean up
        testDb.close();
        if (FileSystem.exists("test.db")) {
            FileSystem.deleteFile("test.db");
        }
    }

    static function assert(condition: Bool, message: String) {
        testTotal++;
        currentTest = message;
        if (condition) {
            testPassed++;
            Sys.println("✅ " + message);
        } else {
            Sys.println("❌ " + message);
        }
    }

    static function assertEquals(expected: Dynamic, actual: Dynamic, message: String) {
        testTotal++;
        currentTest = message;
        if (expected == actual) {
            testPassed++;
            Sys.println("✅ " + message);
        } else {
            Sys.println("❌ " + message + " (expected: " + expected + ", got: " + actual + ")");
        }
    }

    static function assertNotNull(value: Dynamic, message: String) {
        testTotal++;
        currentTest = message;
        if (value != null) {
            testPassed++;
            Sys.println("✅ " + message);
        } else {
            Sys.println("❌ " + message + " (value was null)");
        }
    }

    static function testBasicOperations() {
        Sys.println("\n\033[1mTesting Basic Operations\033[0m");

		// Test both typed and fully dynamic document type
        var users:Collection<User> = cast testDb.collection("users");
        var posts = testDb.collection("posts");

        // Test insert
        var userId = users.insert({
            name: "John Doe",
            email: "john@example.com",
            age: 30,
            active: true
        });
        assert(userId > 0, "Insert should return positive ID");

        // Test findById
        var user = users.findById(userId);
        assertNotNull(user, "findById should return user");
        assertEquals("John Doe", user.name, "User name should match");
        assertEquals("john@example.com", user.email, "User email should match");
        assertEquals(30, user.age, "User age should match");
        assertEquals(true, user.active, "User active should match");

        // Test automatic fields
        assertNotNull(user._id, "User should have _id field");
        assertNotNull(user._createdAt, "User should have _createdAt field");
        assertNotNull(user._updatedAt, "User should have _updatedAt field");

        // Test find all
        var allUsers = users.find();
        assertEquals(1, allUsers.length, "Should find 1 user");

        // Test find with query
        var activeUsers = users.find({active: true});
        assertEquals(1, activeUsers.length, "Should find 1 active user");

        var inactiveUsers = users.find({active: false});
        assertEquals(0, inactiveUsers.length, "Should find 0 inactive users");

        // Test findOne
        var foundUser = users.findOne({name: "John Doe"});
        assertNotNull(foundUser, "findOne should return user");
        assertEquals("John Doe", foundUser.name, "Found user name should match");

        // Test update
        var updated = users.update({name: "John Doe"}, {age: 31, city: "New York"});
        assertEquals(1, updated, "Should update 1 user");

        var updatedUser = users.findById(userId);
        assertEquals(31, updatedUser.age, "Age should be updated");
        assertEquals("New York", updatedUser.city, "City should be added");

        // Test updateById
        var updateResult = users.updateById(userId, {status: "premium"});
        assert(updateResult, "updateById should return true");

        var premiumUser = users.findById(userId);
        assertEquals("premium", premiumUser.status, "Status should be updated");

        // Test count
        var userCount = users.count();
        assertEquals(1, userCount, "Should count 1 user");

        var activeCount = users.count({active: true});
        assertEquals(1, activeCount, "Should count 1 active user");

        // Test multiple collections
        var postId = posts.insert({
            title: "First Post",
            content: "Hello World",
            authorId: userId,
            published: true
        });
        assert(postId > 0, "Post insert should return positive ID");

        var postCount = posts.count();
        assertEquals(1, postCount, "Should count 1 post");

        // Test delete
        var deleted = users.delete({name: "NonExistent"});
        assertEquals(0, deleted, "Should delete 0 non-existent users");

        // Test deleteById
        var deleteResult = posts.deleteById(postId);
        assert(deleteResult, "deleteById should return true");

        var remainingPosts = posts.count();
        assertEquals(0, remainingPosts, "Should have 0 posts after deletion");
    }

    static function testQueryOperators() {
        Sys.println("\n\033[1mTesting Query Operators\033[0m");

        var products = testDb.collection("products");

        // Insert test data
        products.insert({name: "Laptop", price: 999.99, category: "electronics", stock: 10});
        products.insert({name: "Mouse", price: 29.99, category: "electronics", stock: 50});
        products.insert({name: "Book", price: 19.99, category: "books", stock: 100});
        products.insert({name: "Tablet", price: 499.99, category: "electronics", stock: 25});
        products.insert({name: "Pen", price: 2.99, category: "office", stock: 200});

        // Test comparison operators
        var expensiveProducts = products.find({price: {_gt: 100}});
        assertEquals(2, expensiveProducts.length, "Should find 2 products > $100");

        var affordableProducts = products.find({price: {_lte: 30}});
        assertEquals(3, affordableProducts.length, "Should find 3 products <= $30");

        var midRangeProducts = products.find({price: {_gte: 20, _lt: 500}});
        assertEquals(2, midRangeProducts.length, "Should find 2 products in $20-$500 range");

        var notExpensive = products.find({price: {_ne: 999.99}});
        assertEquals(4, notExpensive.length, "Should find 4 products != $999.99");

        // Test array operators
        var electronicsOrBooks = products.find({category: {_in: ["electronics", "books"]}});
        assertEquals(4, electronicsOrBooks.length, "Should find 4 electronics or books");

        var notOffice = products.find({category: {_nin: ["office"]}});
        assertEquals(4, notOffice.length, "Should find 4 non-office products");

        // Test existence operator
        var hasStock = products.find({stock: {_exists: true}});
        assertEquals(5, hasStock.length, "Should find 5 products with stock field");

        // Test logical operators
        var electronicOrExpensive = products.find({
            _or: ([
                {category: "electronics"},
                {price: {_gt: 100}}
            ] : Array<Dynamic>)
        });
        assertEquals(3, electronicOrExpensive.length, "Should find 3 electronics or expensive products");

        var cheapElectronics = products.find({
            _and: ([
                {category: "electronics"},
                {price: {_lt: 50}}
            ] : Array<Dynamic>)
        });
        assertEquals(1, cheapElectronics.length, "Should find 1 cheap electronics product");

        // Test find with options
        var sortedProducts = products.find({}, {orderBy: "price DESC", limit: 2});
        assertEquals(2, sortedProducts.length, "Should find 2 products with limit");
        assertEquals("Laptop", sortedProducts[0].name, "First product should be most expensive");

        var paginatedProducts = products.find({}, {orderBy: "price ASC", limit: 2, offset: 1});
        assertEquals(2, paginatedProducts.length, "Should find 2 products with pagination");
        assertEquals("Book", paginatedProducts[0].name, "First paginated product should be Book");
    }

    static function testTransactions() {
        Sys.println("\n\033[1mTesting Transactions\033[0m");

        var accounts = testDb.collection("accounts");
        var transactions = testDb.collection("transactions");

        // Setup test accounts
        var account1Id = accounts.insert({name: "Account 1", balance: 1000.0});
        var account2Id = accounts.insert({name: "Account 2", balance: 500.0});

        // Test successful transaction
        testDb.transaction(function() {
            // Transfer $100 from account1 to account2
            var account1 = accounts.findById(account1Id);
            var account2 = accounts.findById(account2Id);

            accounts.updateById(account1Id, {balance: account1.balance - 100});
            accounts.updateById(account2Id, {balance: account2.balance + 100});

            transactions.insert({
                from: account1Id,
                to: account2Id,
                amount: 100.0,
                type: "transfer"
            });
        });

        var finalAccount1 = accounts.findById(account1Id);
        var finalAccount2 = accounts.findById(account2Id);

        assertEquals(900.0, finalAccount1.balance, "Account 1 should have $900");
        assertEquals(600.0, finalAccount2.balance, "Account 2 should have $600");

        var transferCount = transactions.count({type: "transfer"});
        assertEquals(1, transferCount, "Should have 1 transfer transaction");

        // Test transaction rollback
        var initialBalance1 = finalAccount1.balance;
        var initialBalance2 = finalAccount2.balance;

        try {
            testDb.transaction(function() {
                var account1 = accounts.findById(account1Id);
                var account2 = accounts.findById(account2Id);

                accounts.updateById(account1Id, {balance: account1.balance - 200});
                accounts.updateById(account2Id, {balance: account2.balance + 200});

                // Simulate an error
                throw "Transaction error";
            });
        } catch (e: Dynamic) {
            // Expected error
        }

        var rollbackAccount1 = accounts.findById(account1Id);
        var rollbackAccount2 = accounts.findById(account2Id);

        assertEquals(initialBalance1, rollbackAccount1.balance, "Account 1 balance should be unchanged after rollback");
        assertEquals(initialBalance2, rollbackAccount2.balance, "Account 2 balance should be unchanged after rollback");

        // Test manual transaction control
        testDb.beginTransaction();

        accounts.updateById(account1Id, {balance: 1000000});
        var richAccount = accounts.findById(account1Id);
        assertEquals(1000000, richAccount.balance, "Account should be rich during transaction");

        testDb.rollback();

        var normalAccount = accounts.findById(account1Id);
        assertEquals(initialBalance1, normalAccount.balance, "Account should be normal after rollback");
    }

    static function testTypeSystem() {
        Sys.println("\n\033[1mTesting Type System\033[0m");

        var mixed = testDb.collection("mixed_types");

        // Test various data types
        var docId = mixed.insert({
            stringField: "Hello",
            intField: 42,
            floatField: 3.14,
            boolField: true,
            jsonField: {
                nested: "value",
                array: [1, 2, 3]
            },
            nullField: null
        });

        var doc = mixed.findById(docId);
        assertNotNull(doc, "Document should exist");
        assertEquals("Hello", doc.stringField, "String field should be preserved");
        assertEquals(42, doc.intField, "Int field should be preserved");
        assertEquals(3.14, doc.floatField, "Float field should be preserved");
        assertEquals(true, doc.boolField, "Bool field should be preserved");
        assertEquals("value", doc.jsonField.nested, "JSON nested field should be preserved");
        assertEquals(null, doc.nullField, "Null field should be preserved");

        // Test type upgrade (Integer to Real)
        mixed.insert({intField: 10});
        mixed.update({intField: 10}, {intField: 10.5});

        var upgradedDoc = mixed.findOne({intField: 10.5});
        assertNotNull(upgradedDoc, "Should find document with upgraded type");
        assertEquals(10.5, upgradedDoc.intField, "Integer field should upgrade to Real");

        // Test field type information
        var fieldTypes = mixed.getFieldTypes();
        assertNotNull(fieldTypes, "Should get field types map");
        assert(fieldTypes.exists("stringField"), "Should have string field type");
        assert(fieldTypes.exists("floatField"), "Should have float field type");
        assert(fieldTypes.exists("boolField"), "Should have bool field type");
        assert(fieldTypes.exists("jsonField"), "Should have JSON field type");
    }

    static function testSchemaEvolution() {
        Sys.println("\n\033[1mTesting Schema Evolution\033[0m");

        var evolving = testDb.collection("evolving");

        // Insert initial document
        var id1 = evolving.insert({name: "Initial", version: 1});

        // Add new field
        var id2 = evolving.insert({
            name: "Enhanced",
            version: 2,
            newField: "Added later"
        });

        // Verify both documents exist
        var doc1 = evolving.findById(id1);
        var doc2 = evolving.findById(id2);

        assertNotNull(doc1, "Initial document should exist");
        assertNotNull(doc2, "Enhanced document should exist");

        assertEquals("Initial", doc1.name, "Initial document name should match");
        assertEquals("Enhanced", doc2.name, "Enhanced document name should match");
        assertEquals("Added later", doc2.newField, "New field should be present");

        // Update old document with new field
        evolving.updateById(id1, {newField: "Updated"});

        var updatedDoc1 = evolving.findById(id1);
        assertEquals("Updated", updatedDoc1.newField, "Old document should have new field");

        // Test querying with new field
        var withNewField = evolving.find({newField: {_exists: true}});
        assertEquals(2, withNewField.length, "Should find 2 documents with new field");

        var withoutNewField = evolving.find({newField: {_exists: false}});
        assertEquals(0, withoutNewField.length, "Should find 0 documents without new field");
    }

    static function testIndexManagement() {
        Sys.println("\n\033[1mTesting Index Management\033[0m");

        var indexed = testDb.collection("test_indexes");

        // Create unique index (createIndex now handles missing columns)
        indexed.createIndex({
            name: "idx_email",
            fields: ["email"],
            unique: true
        });

        // Insert first document
        var id1 = indexed.insert({email: "unique@test.com", name: "User 1"});
        assert(id1 > 0, "Should insert document with unique email");

        // Try to insert duplicate (should not cause error in this implementation)
        try {
            var id2 = indexed.insert({email: "unique@test.com", name: "User 2"});
            // Note: SQLite unique constraint would normally prevent this
            // But our implementation doesn't enforce uniqueness at application level
        } catch (e: Dynamic) {
            // Expected if uniqueness is enforced
        }

        // Create non-unique index (createIndex now handles missing columns)
        indexed.createIndex({
            name: "idx_category",
            fields: ["category"],
            unique: false
        });

        // Insert documents with same category
        indexed.insert({email: "user1@test.com", category: "test"});
        indexed.insert({email: "user2@test.com", category: "test"});

        var sameCategory = indexed.find({category: "test"});
        assertEquals(2, sameCategory.length, "Should find 2 documents with same category");

        // Drop index
        indexed.dropIndex("idx_category");

        // Index should still work for queries (data remains)
        var stillThere = indexed.find({category: "test"});
        assertEquals(2, stillThere.length, "Data should still be queryable after dropping index");
    }

    static function testEdgeCases() {
        Sys.println("\n\033[1mTesting Edge Cases\033[0m");

        var edge = testDb.collection("edge_cases");

        // Test empty document
        var emptyId = edge.insert({});
        var emptyDoc = edge.findById(emptyId);
        assertNotNull(emptyDoc, "Should insert and find empty document");
        assertNotNull(emptyDoc._id, "Empty document should have _id");

        // Test document with special characters
        var specialId = edge.insert({
            name: "Special'Chars\"Test",
            content: "Content with\nnewlines\tand\ttabs"
        });
        var specialDoc = edge.findById(specialId);
        assertEquals("Special'Chars\"Test", specialDoc.name, "Should handle special characters");

        // Test very long string
        var longString = "";
        for (i in 0...1000) {
            longString += "x";
        }
        var longId = edge.insert({longField: longString});
        var longDoc = edge.findById(longId);
        assertEquals(1000, longDoc.longField.length, "Should handle long strings");

        // Test nested JSON
        var nestedId = edge.insert({
            deep: {
                level1: {
                    level2: {
                        level3: "deep value"
                    }
                }
            }
        });
        var nestedDoc = edge.findById(nestedId);
        assertEquals("deep value", nestedDoc.deep.level1.level2.level3, "Should handle deeply nested JSON");

        // Test array with mixed types
        var arrayId = edge.insert({
            mixedArray: ([1, "string", true, {nested: "object"}, null] : Array<Dynamic>)
        });
        var arrayDoc = edge.findById(arrayId);
        assertEquals(5, arrayDoc.mixedArray.length, "Should handle mixed type arrays");
        assertEquals("string", arrayDoc.mixedArray[1], "Should preserve array element types");

        // Test update with null
        edge.update({longField: {_exists: true}}, {longField: null});
        var nullifiedDoc = edge.findById(longId);
        assertEquals(null, nullifiedDoc.longField, "Should handle null updates");

        // Test find with no results
        var noResults = edge.find({nonExistentField: "value"});
        assertEquals(0, noResults.length, "Should return empty array for no results");

        var noResult = edge.findOne({nonExistentField: "value"});
        assertEquals(null, noResult, "Should return null for no result");
    }

    static function testErrorHandling() {
        Sys.println("\n\033[1mTesting Error Handling\033[0m");

        var errors = testDb.collection("errors");

        // Test findById with non-existent ID
        var nonExistent = errors.findById(99999);
        assertEquals(null, nonExistent, "Should return null for non-existent ID");

        // Test updateById with non-existent ID
        var updateResult = errors.updateById(99999, {field: "value"});
        assertEquals(false, updateResult, "Should return false for non-existent ID update");

        // Test deleteById with non-existent ID
        var deleteResult = errors.deleteById(99999);
        assertEquals(false, deleteResult, "Should return false for non-existent ID deletion");

        // Test count with empty collection
        var emptyCount = errors.count();
        assertEquals(0, emptyCount, "Should return 0 for empty collection count");

        // Test transaction error handling
        var initialCount = errors.count();

        try {
            testDb.beginTransaction();
            errors.insert({test: "value"});
            testDb.rollback();
        } catch (e: Dynamic) {
            // Should not throw
        }

        var finalCount = errors.count();
        assertEquals(initialCount, finalCount, "Count should be unchanged after rollback");
    }

    static function testIndexOrderIndependence() {
        Sys.println("\n\033[1mTesting Index Order Independence\033[0m");

        // Test Scenario A: Insert first, then create index
        var collectionA = testDb.collection("order_test_a");
        collectionA.insert({price: 999, category: "electronics"});
        collectionA.createIndex({name: "idx_price_a", fields: ["price"]});

        var priceTypesA = collectionA.getFieldTypes();
        var priceTypeA = priceTypesA.get("price");

        // Test Scenario B: Create index first, then insert
        var collectionB = testDb.collection("order_test_b");
        collectionB.createIndex({name: "idx_price_b", fields: ["price"]});
        collectionB.insert({price: 999, category: "electronics"});

        var priceTypesB = collectionB.getFieldTypes();
        var priceTypeB = priceTypesB.get("price");

        // Both should result in the same field type
        assertEquals(priceTypeA, priceTypeB, "Field types should be identical regardless of index creation order");

        // Both should have INTEGER type for the price field
        assert(priceTypeA == FTInteger, "Price field should be detected as INTEGER");

        // Test queries work identically
        var resultA = collectionA.find({price: {_gte: 500}});
        var resultB = collectionB.find({price: {_gte: 500}});

        assertEquals(resultA.length, resultB.length, "Query results should be identical");
        assertEquals(1, resultA.length, "Should find 1 product in scenario A");
        assertEquals(1, resultB.length, "Should find 1 product in scenario B");

        // Test more complex type upgrade: TEXT -> INTEGER
        var collectionC = testDb.collection("order_test_c");
        collectionC.createIndex({name: "idx_age_c", fields: ["age"]});  // Creates as TEXT
        collectionC.insert({name: "John", age: 25});  // Should upgrade to INTEGER

        var ageTypesC = collectionC.getFieldTypes();
        var ageTypeC = ageTypesC.get("age");
        assert(ageTypeC == FTInteger, "Age field should be upgraded from TEXT to INTEGER");

        // Verify index still works after type upgrade
        var adultQuery = collectionC.find({age: {_gte: 18}});
        assertEquals(1, adultQuery.length, "Index should work correctly after type upgrade");
    }

    static function testDataPersistence() {
        Sys.println("\n\033[1mTesting Data Persistence\033[0m");

        // Test data persistence within same session
        var persistentCollection = testDb.collection("persistent_data");

        // Insert test data
        var userId1 = persistentCollection.insert({
            name: "Alice",
            email: "alice@example.com",
            age: 30,
            settings: {theme: "dark", notifications: true}
        });

        var userId2 = persistentCollection.insert({
            name: "Bob",
            email: "bob@example.com",
            age: 25,
            preferences: ["gaming", "music", "sports"]
        });

        // Verify data exists in same session
        var aliceInSameSession = persistentCollection.findById(userId1);
        assertNotNull(aliceInSameSession, "Alice should exist in same session");
        assertEquals("Alice", aliceInSameSession.name, "Alice name should match in same session");
        assertEquals("alice@example.com", aliceInSameSession.email, "Alice email should match in same session");
        assertEquals(30, aliceInSameSession.age, "Alice age should match in same session");
        assertEquals("dark", aliceInSameSession.settings.theme, "Alice settings should be preserved in same session");
        assertEquals(true, aliceInSameSession.settings.notifications, "Alice notifications setting should be preserved");

        var bobInSameSession = persistentCollection.findById(userId2);
        assertNotNull(bobInSameSession, "Bob should exist in same session");
        assertEquals("Bob", bobInSameSession.name, "Bob name should match in same session");
        assertEquals(3, bobInSameSession.preferences.length, "Bob preferences array length should be preserved");
        assertEquals("gaming", bobInSameSession.preferences[0], "Bob first preference should be preserved");

        // Create an index to test index persistence
        persistentCollection.createIndex({
            name: "idx_persistent_email",
            fields: ["email"],
            unique: true
        });

        // Verify index works in same session
        var aliceByEmail = persistentCollection.findOne({email: "alice@example.com"});
        assertNotNull(aliceByEmail, "Should find Alice by email using index in same session");
        assertEquals("Alice", aliceByEmail.name, "Found user should be Alice");

        // Get current count
        var countInSameSession = persistentCollection.count({});
        assertEquals(2, countInSameSession, "Should have 2 documents in same session");

        // Close current database connection
        testDb.close();

        // Test cross-session persistence by creating new Jimjam instance
        Sys.println("\n\033[1mTesting Cross-Session Persistence\033[0m");
        var newDb = new Jimjam("test.db");
        var newSessionCollection = newDb.collection("persistent_data");

        // Verify data persists across sessions
        var aliceInNewSession = newSessionCollection.findById(userId1);
        assertNotNull(aliceInNewSession, "Alice should exist in new session");
        assertEquals("Alice", aliceInNewSession.name, "Alice name should match in new session");
        assertEquals("alice@example.com", aliceInNewSession.email, "Alice email should match in new session");
        assertEquals(30, aliceInNewSession.age, "Alice age should match in new session");
        assertEquals("dark", aliceInNewSession.settings.theme, "Alice settings should persist across sessions");
        assertEquals(true, aliceInNewSession.settings.notifications, "Alice notifications should persist across sessions");

        var bobInNewSession = newSessionCollection.findById(userId2);
        assertNotNull(bobInNewSession, "Bob should exist in new session");
        assertEquals("Bob", bobInNewSession.name, "Bob name should match in new session");
        assertEquals(3, bobInNewSession.preferences.length, "Bob preferences should persist across sessions");
        assertEquals("gaming", bobInNewSession.preferences[0], "Bob preferences content should persist");
        assertEquals("music", bobInNewSession.preferences[1], "Bob second preference should persist");
        assertEquals("sports", bobInNewSession.preferences[2], "Bob third preference should persist");

        // Verify count persists across sessions
        var countInNewSession = newSessionCollection.count({});
        assertEquals(2, countInNewSession, "Should have 2 documents in new session");

        // Verify index works across sessions
        var aliceByEmailNewSession = newSessionCollection.findOne({email: "alice@example.com"});
        assertNotNull(aliceByEmailNewSession, "Should find Alice by email in new session");
        assertEquals("Alice", aliceByEmailNewSession.name, "Found user should be Alice in new session");

        // Test adding data in new session
        var userId3 = newSessionCollection.insert({
            name: "Charlie",
            email: "charlie@example.com",
            age: 35,
            metadata: {created: "new_session", version: 2}
        });

        // Verify new data exists
        var charlieInNewSession = newSessionCollection.findById(userId3);
        assertNotNull(charlieInNewSession, "Charlie should exist in new session");
        assertEquals("Charlie", charlieInNewSession.name, "Charlie name should match");
        assertEquals("new_session", charlieInNewSession.metadata.created, "Charlie metadata should be preserved");

        // Verify total count after adding Charlie
        var finalCount = newSessionCollection.count({});
        assertEquals(3, finalCount, "Should have 3 documents after adding Charlie");

        // Test schema evolution persistence - add new field type
        var userId4 = newSessionCollection.insert({
            name: "Diana",
            email: "diana@example.com",
            age: 28,
            isActive: true,  // New boolean field
            score: 95.5      // New float field
        });

        var dianaInNewSession = newSessionCollection.findById(userId4);
        assertNotNull(dianaInNewSession, "Diana should exist in new session");
        assertEquals(true, dianaInNewSession.isActive, "Diana boolean field should be preserved");
        assertEquals(95.5, dianaInNewSession.score, "Diana float field should be preserved");

        // Close new session
        newDb.close();

        // Test that schema changes persist by opening another session
        var thirdDb = new Jimjam("test.db");
        var thirdSessionCollection = thirdDb.collection("persistent_data");

        // Verify all data persists including schema changes
        var finalCountThirdSession = thirdSessionCollection.count({});
        assertEquals(4, finalCountThirdSession, "Should have 4 documents in third session");

        var dianaInThirdSession = thirdSessionCollection.findById(userId4);
        assertNotNull(dianaInThirdSession, "Diana should exist in third session");
        assertEquals(true, dianaInThirdSession.isActive, "Diana boolean should persist across multiple sessions");
        assertEquals(95.5, dianaInThirdSession.score, "Diana float should persist across multiple sessions");

        // Test field types are properly maintained
        var fieldTypes = thirdSessionCollection.getFieldTypes();
        assert(fieldTypes.exists("isActive"), "Boolean field type should be tracked");
        assert(fieldTypes.exists("score"), "Float field type should be tracked");

        // Close third session
        thirdDb.close();

        // Re-open original testDb for cleanup
        testDb = new Jimjam("test.db");
    }

    static function printResults() {
		Sys.println("\n\033[1m- Test Results -\033[0m");
        Sys.println("Passed: " + testPassed + "/" + testTotal);
        Sys.println("Success Rate: " + Math.round((testPassed / testTotal) * 100) + "%");

        if (testPassed == testTotal) {
            Sys.println("🎉 All tests passed!");
			Sys.exit(0);
        } else {
            Sys.println("❌ " + (testTotal - testPassed) + " tests failed");
			Sys.exit(-1);
        }
    }
}
