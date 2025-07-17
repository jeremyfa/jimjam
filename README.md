# Jimjam - NoSQL Database for Haxe

A flexible, MongoDB-style document database built on SQLite for Haxe applications. Combines the simplicity of NoSQL with the reliability of SQLite, featuring natural dot notation for field access.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [API Reference](#api-reference)
  - [Database Operations](#database-operations)
  - [Collection Operations](#collection-operations)
  - [Query Operators](#query-operators)
  - [Transactions](#transactions)
  - [Indexes](#indexes)
- [Examples](#examples)
- [Type System](#type-system)
- [Best Practices](#best-practices)
- [Performance Tips](#performance-tips)

## Features

- **Natural Dot Notation**: Access fields directly with `doc.fieldName`
- **Collection-Based API**: Clean separation between database and collections
- **Dynamic Schema**: Automatically creates columns as needed
- **Type Preservation**: Maintains Integer, Float, Boolean, and JSON types
- **MongoDB-style Queries**: Familiar query syntax with operators like `_gt`, `_in`, `_or`
- **Multi-Collection Transactions**: ACID transactions across multiple collections
- **Automatic Type Upgrades**: Seamlessly upgrades Integer fields to Float when needed
- **Index Management**: Create and manage indexes for better performance
- **Automatic Timestamps**: Built-in `_createdAt` and `_updatedAt` fields
- **Zero Dependencies**: Uses only Haxe's built-in SQLite support

## Installation

```
haxelib install jimjam
```

**Supported Targets**: Currently tested on PHP and C++ (including CPPIA) targets.

## Quick Start

```haxe
import jimjam.Jimjam;

class QuickStart {
    static function main() {
        // Create database
        var db = new Jimjam("myapp.db");

        // Get collections
        var users = db.collection("users");
        var posts = db.collection("posts");

        // Insert documents
        var userId = users.insert({
            name: "Alice Johnson",
            email: "alice@example.com",
            age: 28,
            active: true
        });

        // Find with dot notation
        var user = users.findById(userId);
        trace("User: " + user.name);

        // Query with operators
        var adults = users.find({age: {_gte: 18}});
        for (adult in adults) {
            trace(adult.name + " is " + adult.age + " years old");
        }

        // Multi-collection transaction
        db.transaction(function() {
            posts.insert({
                userId: userId,
                title: "My First Post",
                content: "Hello, World!"
            });

            users.updateById(userId, {
                postCount: 1
            });
        });

        // Close when done
        db.close();
    }
}
```

## Core Concepts

### Database and Collections

Jimjam uses a two-level structure:
- **Database** (`Jimjam`): Manages the connection and transactions
- **Collections** (`Collection`): Handle documents within tables

```haxe
var db = new Jimjam("myapp.db");
var users = db.collection("users");
var orders = db.collection("orders");
var products = db.collection("products");
```

### Documents

Documents can be either dynamic objects or typed structures. Jimjam supports both approaches for maximum flexibility.

#### Dynamic Documents

Documents are dynamic objects that can contain any fields:

```haxe
// Create documents using anonymous objects
var doc: Dynamic = {
    name: "John Doe",
    age: 30,
    active: true,
    scores: [85, 92, 78],
    metadata: {
        created: "2024-01-01",
        tags: ["vip", "verified"]
    }
};

// Or build them dynamically
var doc: Document = {};
doc.name = "Jane Smith";
doc.email = "jane@example.com";
doc.preferences = {
    theme: "dark",
    language: "en"
};
```

#### Typed Documents

For better type safety, you can define typed structures and get typed collections:

```haxe
// Define a typed document structure
typedef User = {
    > Document,  // Extends base Document (includes _id, _createdAt, _updatedAt)
    name: String,
    email: String,
    age: Int,
    active: Bool,
    ?city: String,      // Optional field
    ?status: String     // Optional field
}

// Get a typed collection
var users: Collection<User> = cast db.collection("users");

// Insert typed documents - full type checking
var userId = users.insert({
    name: "Alice Johnson",
    email: "alice@example.com",
    age: 28,
    active: true
});

// Find operations return typed documents
var user = users.findById(userId);
if (user != null) {
    trace("User: " + user.name + " (" + user.age + ")");
    // Full autocomplete and type safety on user.* properties
}

// Query with type safety
var activeUsers = users.find({active: true});
for (user in activeUsers) {
    trace(user.name); // Typed access
}
```

Both approaches can be mixed - you can use dynamic documents for flexible data and typed documents where you need structure and type safety.

### Automatic Fields

Every document automatically gets:
- `_id`: Unique auto-incrementing identifier
- `_createdAt`: Timestamp when document was created
- `_updatedAt`: Timestamp of last update (automatically maintained)

## API Reference

### Database Operations

#### Constructor

```haxe
new Jimjam(dbPath: String)
```

Creates or opens a database.

```haxe
var db = new Jimjam("myapp.db");
```

#### collection()

```haxe
public function collection(name: String): Collection
```

Gets or creates a collection. Collections are cached, so calling this multiple times with the same name returns the same instance.

```haxe
var users = db.collection("users");
var orders = db.collection("orders");
```

#### beginTransaction() / commit() / rollback()

```haxe
public function beginTransaction(): Void
public function commit(): Void
public function rollback(): Void
```

Manual transaction control. All operations on all collections participate in the transaction.

```haxe
db.beginTransaction();
try {
    users.insert({name: "Alice"});
    orders.insert({userId: 1, total: 99.99});
    db.commit();
} catch (e: Dynamic) {
    db.rollback();
}
```

#### transaction()

```haxe
public function transaction(fn: () -> Void): Void
```

Use regular transactions for **coordinated writes** that don't depend on reading data within the transaction. Perfect for simple operations where you just need to ensure multiple writes happen atomically.

```haxe
// Good use case: Simple coordinated writes
db.transaction(function() {
    var userId = users.insert({name: "Bob"});
    var orderId = orders.insert({userId: userId, total: 99.99});
    // All operations are atomic, no reads involved
});
```

#### immediateTransaction()

```haxe
public function immediateTransaction(fn: () -> Void): Void
```

Use immediate transactions when you need to **read data within the transaction** to make decisions. Immediate transactions acquire an exclusive write lock immediately, ensuring that no other transactions can read or write data until completion. This provides a consistent snapshot for all operations within the transaction. Reads from outside of transactions can still happen in parallel.

**Key rule**: If your transaction reads data to make decisions, use `immediateTransaction()`.

```haxe
// Good use case: Read-then-write operations
db.immediateTransaction(function() {
    var account = accounts.findById(accountId);
    if (account.balance >= 100) {
        accounts.updateById(accountId, {balance: account.balance - 100});
        transactions.insert({accountId: accountId, amount: -100});
    }
    // Consistent read ensures balance doesn't change between read and write
});
```

#### close()

```haxe
public function close(): Void
```

Closes the database connection.

```haxe
db.close();
```

### Collection Operations

#### insert()

```haxe
public function insert(doc: Document): Int
```

Inserts a new document and returns its ID.

```haxe
var id = users.insert({
    name: "Product A",
    price: 29.99,
    inStock: true
});
```

#### find()

```haxe
public function find(?query: Query, ?options: {?limit: Int, ?offset: Int, ?orderBy: String}): Array<Document>
```

Finds all documents matching the query.

```haxe
// Find all
var all = users.find();

// Find with criteria
var activeUsers = users.find({active: true});

// Find with options
var topScores = users.find(
    {category: "game"},
    {
        orderBy: "score DESC",
        limit: 10
    }
);

// Pagination
var page2 = users.find(
    {status: "published"},
    {
        orderBy: "_createdAt DESC",
        limit: 20,
        offset: 20
    }
);
```

#### findOne()

```haxe
public function findOne(?query: Query): Null<Document>
```

Finds a single document matching the query.

```haxe
var user = users.findOne({email: "alice@example.com"});
if (user != null) {
    trace("Welcome, " + user.name);
}
```

#### findById()

```haxe
public function findById(id: Int): Null<Document>
```

Finds a document by its `_id` field.

```haxe
var doc = users.findById(123);
```

#### update()

```haxe
public function update(query: Query, updates: Document): Int
```

Updates all documents matching the query. Returns count of updated documents.

```haxe
// Update single field
users.update({status: "pending"}, {status: "approved"});

// Update multiple fields
var updated = users.update(
    {age: {_gte: 18}},
    {
        canVote: true,
        category: "adult"
    }
);
trace("Updated " + updated + " records");
```

#### updateById()

```haxe
public function updateById(id: Int, updates: Document): Bool
```

Updates a single document by ID.

```haxe
users.updateById(userId, {
    lastLogin: Date.now(),
    loginCount: user.loginCount + 1
});
```

#### delete()

```haxe
public function delete(query: Query): Int
```

Deletes all documents matching the query.

```haxe
var deleted = users.delete({
    status: "inactive",
    lastLogin: {_lt: thirtyDaysAgo}
});
```

#### deleteById()

```haxe
public function deleteById(id: Int): Bool
```

Deletes a document by ID.

```haxe
if (users.deleteById(123)) {
    trace("User deleted");
}
```

#### count()

```haxe
public function count(?query: Query): Int
```

Counts documents matching the query.

```haxe
var total = users.count();
var active = users.count({active: true});
```

#### createIndex() / dropIndex()

```haxe
public function createIndex(index: IndexDef): Void
public function dropIndex(indexName: String): Void
```

Manages indexes for the collection.

```haxe
users.createIndex({
    name: "idx_email",
    fields: ["email"],
    unique: true
});
```

### Query Operators

#### Comparison Operators

- **_gt**: Greater than
- **_gte**: Greater than or equal
- **_lt**: Less than
- **_lte**: Less than or equal
- **_ne**: Not equal

```haxe
users.find({age: {_gt: 21}});
users.find({price: {_gte: 10, _lte: 100}});
```

#### Array Operators

- **_in**: Value in array
- **_nin**: Value not in array

```haxe
users.find({status: {_in: ["active", "pending"]}});
users.find({role: {_nin: ["admin", "moderator"]}});
```

#### Existence Operator

- **_exists**: Field exists or not

```haxe
users.find({email: {_exists: true}});
```

#### Pattern Matching

- **_regex**: Regular expression

```haxe
users.find({email: {_regex: ".*@example\\.com$"}});
```

#### Logical Operators

- **_or**: Logical OR
- **_and**: Logical AND
- **_not**: Logical NOT

```haxe
users.find({
    _or: [
        {age: {_lt: 18}},
        {age: {_gt: 65}}
    ]
});

users.find({
    _and: [
        {category: "electronics"},
        {price: {_lte: 1000}}
    ]
});
```

### Transactions

#### Simple Transaction (Coordinated Writes)

```haxe
var db = new Jimjam("shop.db");
var users = db.collection("users");
var orders = db.collection("orders");

// Use regular transaction for simple coordinated writes
db.transaction(function() {
    var userId = users.insert({
        name: "Alice",
        email: "alice@example.com"
    });

    orders.insert({
        userId: userId,
        items: ["A", "B"],
        total: 59.99
    });
    // No reads involved - just coordinated writes
});
```

#### Complex Multi-Collection Transaction (Read-then-Write)

```haxe
var db = new Jimjam("shop.db");
var products = db.collection("products");
var orders = db.collection("orders");
var orderItems = db.collection("order_items");
var customers = db.collection("customers");

function completePurchase(customerId: Int, items: Array<{sku: String, qty: Int}>) {
    var orderId: Int = 0;
    var total: Float = 0.0;

    // Use immediateTransaction because we read data to make decisions
    db.immediateTransaction(function() {
        // Verify customer (READ)
        var customer = customers.findById(customerId);
        if (customer == null) {
            throw "Customer not found";
        }

        // Create order
        var orderId = orders.insert({
            customerId: customerId,
            status: "pending",
            orderDate: Date.now(),
            total: 0.0
        });

        var total = 0.0;

        // Process items
        for (item in items) {
            // Check product availability (READ)
            var product = products.findOne({sku: item.sku});
            if (product == null || product.stock < item.qty) {
                throw "Product unavailable: " + item.sku;
            }

            // Update inventory based on read data (WRITE)
            products.update(
                {sku: item.sku},
                {stock: product.stock - item.qty}
            );

            // Add order item
            orderItems.insert({
                orderId: orderId,
                sku: item.sku,
                quantity: item.qty,
                price: product.price
            });

            total += product.price * item.qty;
        }

        // Update order total
        orders.updateById(orderId, {total: total});

        // Update customer based on read data (WRITE)
        customers.updateById(customerId, {
            lastOrderDate: Date.now(),
            totalSpent: customer.totalSpent + total
        });
    });

    return {orderId: orderId, total: total};
}
```

## Examples

### User Management System

```haxe
class UserManager {
    var db: Jimjam;
    var users: Collection;
    var sessions: Collection;

    public function new() {
        db = new Jimjam("users.db");
        users = db.collection("users");
        sessions = db.collection("sessions");

        // Create indexes
        users.createIndex({
            name: "idx_email",
            fields: ["email"],
            unique: true
        });

        users.createIndex({
            name: "idx_username",
            fields: ["username"],
            unique: true
        });
    }

    public function createUser(username: String, email: String, password: String) {
        // Check if exists
        if (users.findOne({_or: [{username: username}, {email: email}]}) != null) {
            throw "User already exists";
        }

        return users.insert({
            username: username,
            email: email,
            password: haxe.crypto.Sha256.encode(password),
            active: true,
            role: "user",
            loginCount: 0,
            createdAt: Date.now()
        });
    }

    public function login(username: String, password: String): Null<String> {
        var sessionId: String = null;

        // Use immediateTransaction because we read user data to make decisions
        db.immediateTransaction(function() {
            var user = users.findOne({
                username: username,
                password: haxe.crypto.Sha256.encode(password),
                active: true
            });

            if (user == null) return null;

            // Update login info based on read data
            users.updateById(user._id, {
                lastLogin: Date.now(),
                loginCount: user.loginCount + 1
            });

            // Create session
            var sessionId = generateSessionId();
            sessions.insert({
                sessionId: sessionId,
                userId: user._id,
                createdAt: Date.now(),
                expiresAt: Date.now() + 86400000 // 24 hours
            });
        });

        return sessionId;
    }

    public function findInactiveUsers(days: Int) {
        var cutoff = Date.now() - (days * 24 * 60 * 60 * 1000);
        return users.find({
            _or: [
                {lastLogin: {_lt: cutoff}},
                {lastLogin: {_exists: false}}
            ]
        });
    }

    public function close() {
        db.close();
    }
}
```

### Blog System

```haxe
class BlogSystem {
    var db: Jimjam;
    var posts: Collection;
    var comments: Collection;
    var tags: Collection;

    public function new() {
        db = new Jimjam("blog.db");
        posts = db.collection("posts");
        comments = db.collection("comments");
        tags = db.collection("tags");
    }

    public function createPost(authorId: Int, title: String, content: String, tagNames: Array<String>) {
        var postId: Int = 0;

        // Use immediateTransaction because we read tag data to make decisions
        db.immediateTransaction(function() {
            // Create post
            var postId = posts.insert({
                authorId: authorId,
                title: title,
                content: content,
                status: "draft",
                views: 0,
                likes: 0
            });

            // Handle tags - read existing tags to decide whether to create or update
            for (tagName in tagNames) {
                var tag = tags.findOne({name: tagName});
                if (tag == null) {
                    tags.insert({
                        name: tagName,
                        posts: [postId],
                        count: 1
                    });
                } else {
                    tag.posts.push(postId);
                    tags.updateById(tag._id, {
                        posts: tag.posts,
                        count: tag.count + 1
                    });
                }
            }
        });

        return postId;
    }

    public function addComment(postId: Int, authorId: Int, content: String) {
        var commentId: Int = 0;

        // Use immediateTransaction because we read post data to make decisions
        db.immediateTransaction(function() {
            var post = posts.findById(postId);
            if (post == null) throw "Post not found";

            var commentId = comments.insert({
                postId: postId,
                authorId: authorId,
                content: content,
                likes: 0
            });

            // Update comment count based on read data
            posts.updateById(postId, {
                commentCount: post.commentCount + 1,
                lastActivity: Date.now()
            });
        });

        return commentId;
    }

    public function getPopularPosts(limit: Int = 10) {
        return posts.find(
            {status: "published"},
            {
                orderBy: "views DESC, likes DESC",
                limit: limit
            }
        );
    }

    public function searchPosts(searchTerm: String) {
        return posts.find({
            _or: [
                {title: {_regex: '.*$searchTerm.*'}},
                {content: {_regex: '.*$searchTerm.*'}}
            ]
        });
    }
}
```

## Type System

### Type Preservation

Jimjam automatically detects and preserves types:

```haxe
var products = db.collection("products");

// Insert with various types
products.insert({
    name: "Widget",           // Text
    price: 29.99,            // Real
    quantity: 100,           // Integer (will use REAL column)
    inStock: true,           // Boolean
    specs: {                 // JSON
        color: "blue",
        size: "medium"
    }
});

// Types are preserved when reading
var product = products.findOne({name: "Widget"});
trace(product.price);        // 29.99 (Float)
trace(product.inStock);      // true (Bool)
trace(product.specs.color);  // "blue"
```

### Automatic Type Upgrades

When a Float value is assigned to an Integer field, it automatically upgrades:

```haxe
// Initially integer
products.insert({productId: 1, rating: 4});

// Later update with float - type upgrades
products.update({productId: 1}, {rating: 4.5});

// Future inserts treat rating as Real
products.insert({productId: 2, rating: 5}); // Stored as 5.0
```

## Best Practices

### 1. Use Collections Consistently

```haxe
// Good - get collection once
var users = db.collection("users");
users.insert({...});
users.find({...});

// Less efficient - gets collection each time
db.collection("users").insert({...});
db.collection("users").find({...});
```

### 2. Choose the Right Transaction Type

#### For Simple Coordinated Writes (No Reads)
```haxe
// Good - use regular transaction for coordinated writes
db.transaction(function() {
    var userId = users.insert({name: "John", email: "john@example.com"});
    var profileId = profiles.insert({userId: userId, bio: "Welcome!"});
    var settingsId = settings.insert({userId: userId, theme: "light"});
    // All writes, no reads - regular transaction is perfect
});
```

#### For Read-then-Write Operations
```haxe
// Good - use immediateTransaction when reading data to make decisions
db.immediateTransaction(function() {
    var user = users.findById(userId);
    var currentPosts = posts.count({authorId: userId});

    users.updateById(userId, {
        postCount: currentPosts,
        lastActivity: Date.now()
    });
    // Reads data first, then writes based on that data
});
```

#### Avoid Non-Atomic Operations
```haxe
// Bad - not atomic, can leave data in inconsistent state
posts.insert({...});
users.update({...});
stats.insert({...});
```

### 3. Create Appropriate Indexes

```haxe
// Index frequently queried fields
users.createIndex({
    name: "idx_email",
    fields: ["email"],
    unique: true
});

// Compound index for complex queries
orders.createIndex({
    name: "idx_user_status_date",
    fields: ["userId", "status", "_createdAt"]
});
```

### 4. Handle Null Values

```haxe
var user = users.findOne({email: email});
if (user != null) {
    trace("Name: " + user.name);

    // Check nested fields
    if (user.profile != null && user.profile.avatar != null) {
        trace("Avatar: " + user.profile.avatar);
    }
}
```

## Performance Tips

### 1. Batch Operations in Transactions

```haxe
db.transaction(function() {
    for (i in 0...10000) {
        items.insert({
            index: i,
            value: Math.random()
        });
    }
});
```

### 2. Use Limits and Pagination

```haxe
// Don't fetch all
var results = posts.find(
    {status: "published"},
    {
        limit: 20,
        offset: page * 20,
        orderBy: "_createdAt DESC"
    }
);
```

### 3. Optimize Queries

```haxe
// Good - specific query
users.find({
    status: "active",
    age: {_gte: 18, _lte: 65},
    country: "US"
});

// Bad - fetch all and filter
var all = users.find();
var filtered = all.filter(u ->
    u.status == "active" &&
    u.age >= 18 &&
    u.age <= 65 &&
    u.country == "US"
);
```
