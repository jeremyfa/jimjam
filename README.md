# Jimjam - NoSQL Database for Haxe

A flexible, MongoDB-style document database built on SQLite for Haxe applications. Combines the simplicity of NoSQL with the reliability of SQLite, featuring natural dot notation for field access and automatic timestamp handling.

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
- [Automatic Timestamps](#automatic-timestamps)
- [Date Handling](#date-handling)
- [Best Practices](#best-practices)
- [Performance Tips](#performance-tips)

## Features

- **Automatic Timestamps with Indexes**: Built-in `_createdAt` and `_updatedAt` fields maintained automatically with pre-built indexes for fast queries
- **Natural Dot Notation**: Access fields directly with `doc.fieldName`
- **Collection-Based API**: Clean separation between database and collections
- **Dynamic Schema**: Automatically creates columns as needed
- **Type Preservation**: Maintains Integer, Float, Boolean, JSON, and Date types
- **Automatic Date Handling**: Dates are stored as UTC timestamps and converted automatically
- **MongoDB-style Queries**: Familiar query syntax with operators like `_gt`, `_in`, `_or`
- **Multi-Collection Transactions**: ACID transactions across multiple collections
- **Automatic Type Upgrades**: Seamlessly upgrades Integer fields to Float when needed
- **Index Management**: Create and manage indexes for better performance
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
        // Create database and collections
        var db = new Jimjam("myapp.db");
        var users = db.collection("users");
        var posts = db.collection("posts");

        // Insert documents
        var userId = users.insert({
            name: "Alice Johnson",
            email: "alice@example.com",
            age: 28,
            active: true
        });

        // Read documents
        var user = users.findById(userId);
        trace("User: " + user.name + " (age " + user.age + ")");

        // Query with operators
        var adults = users.find({age: {_gte: 18}});
        var activeUsers = users.find({active: true});

        // Update documents
        users.updateById(userId, {
            lastLogin: Date.now(),
            loginCount: 1
        });

        // Upsert (insert or update)
        var settingsId = users.upsert({
            type: "preferences",
            theme: "dark",
            notifications: true
        });

        // Multi-collection transaction
        db.transaction(function() {
            var postId = posts.insert({
                userId: userId,
                title: "Welcome to Jimjam!",
                content: "This is my first post."
            });

            users.updateById(userId, {postCount: 1});
        });

        // Query by automatic timestamps
        var recentUsers = users.find({
            _createdAt: {_gte: Date.fromTime(Date.now().getTime() - 86400000)}
        });

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
    ?lastLogin: Date,   // Optional field for actual login time
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
    trace("Account created: " + user._createdAt);
    trace("Last modified: " + user._updatedAt);
}

// Query with type safety
var activeUsers = users.find({active: true});
for (user in activeUsers) {
    trace(user.name + " joined " + user._createdAt);
}
```

### Automatic Fields

Every document automatically gets these fields - **you never need to set them manually**:
- `_id`: Unique auto-incrementing identifier
- `_createdAt`: Timestamp when document was created (never changes) - **automatically indexed**
- `_updatedAt`: Timestamp of last update (automatically updated on every change) - **automatically indexed**

These automatic indexes make time-based queries fast without any additional setup!

## Automatic Timestamps

Jimjam automatically manages creation and update timestamps for every document. These fields are **automatically indexed** for fast time-based queries out of the box!

### How It Works

```haxe
var tasks = db.collection("tasks");

// Insert a document - timestamps are automatic
var taskId = tasks.insert({
    title: "Write documentation",
    priority: "high"
});

var task = tasks.findById(taskId);
trace("Created at: " + task._createdAt);  // Set automatically
trace("Updated at: " + task._updatedAt);  // Initially same as _createdAt

// Wait a moment...
Sys.sleep(1);

// Update the document - _updatedAt changes automatically
tasks.updateById(taskId, {status: "in-progress"});

var updated = tasks.findById(taskId);
trace("Still created at: " + updated._createdAt);  // Unchanged
trace("Now updated at: " + updated._updatedAt);    // Automatically updated!
trace("Status: " + updated.status);
```

### Querying by Timestamps

Use automatic timestamps for powerful time-based queries. Since `_createdAt` and `_updatedAt` are automatically indexed, these queries are fast:

```haxe
// Find documents created in the last hour
var oneHourAgo = Date.fromTime(Date.now().getTime() - 3600000);
var recentDocs = collection.find({_createdAt: {_gte: oneHourAgo}});

// Find documents not updated in 30 days
var thirtyDaysAgo = Date.fromTime(Date.now().getTime() - 2592000000);
var staleDocs = collection.find({_updatedAt: {_lt: thirtyDaysAgo}});

// Find documents created today
var startOfDay = Date.fromTime(Math.floor(Date.now().getTime() / 86400000) * 86400000);
var todaysDocs = collection.find({_createdAt: {_gte: startOfDay}});

// Order by creation time
var newest = collection.find({}, {orderBy: "_createdAt DESC", limit: 10});
var oldest = collection.find({}, {orderBy: "_createdAt ASC", limit: 10});
```

### Real-World Example: Activity Tracking

```haxe
class ActivityTracker {
    var db: Jimjam;
    var users: Collection;
    var activities: Collection;

    public function new() {
        db = new Jimjam("tracker.db");
        users = db.collection("users");
        activities = db.collection("activities");
    }

    public function recordActivity(userId: Int, action: String) {
        // Just insert - timestamps are automatic!
        activities.insert({
            userId: userId,
            action: action,
            // No need for timestamp: Date.now() - use _createdAt instead!
        });

        // Update user's last activity - _updatedAt changes automatically
        users.updateById(userId, {lastAction: action});
    }

    public function getRecentlyActiveUsers(hours: Int = 24) {
        var since = Date.fromTime(Date.now().getTime() - (hours * 3600000));

        // Find users updated recently (any field change updates _updatedAt)
        return users.find({_updatedAt: {_gte: since}});
    }

    public function getUserActivityTimeline(userId: Int, days: Int = 7) {
        var since = Date.fromTime(Date.now().getTime() - (days * 86400000));

        // Get activities using _createdAt for accurate timeline
        return activities.find(
            {
                userId: userId,
                _createdAt: {_gte: since}
            },
            {orderBy: "_createdAt DESC"}
        );
    }

    public function getInactiveUsers(days: Int = 30) {
        var cutoff = Date.fromTime(Date.now().getTime() - (days * 86400000));

        // Users not updated in X days (no activity = no updates)
        return users.find({_updatedAt: {_lt: cutoff}});
    }
}
```

## Date Handling

Besides automatic timestamps, Jimjam provides automatic handling for your own Date fields:

### Date Storage

- Your Date fields are stored as UTC timestamps in `YYYY-MM-DD HH:MM:SS` format
- Automatic conversion handles timezone differences between targets
- Date objects are automatically detected and converted during insert/update
- Retrieved dates are automatically converted back to Date objects

### Working with Custom Date Fields

While `_createdAt` and `_updatedAt` are automatic, you may need custom date fields for domain-specific purposes:

```haxe
var events = db.collection("events");

// Insert with custom Date fields (in addition to automatic timestamps)
var eventId = events.insert({
    name: "Conference",
    startDate: Date.now(),                                    // Event-specific date
    endDate: Date.fromTime(Date.now().getTime() + 86400000), // Event-specific date
});

// All dates work seamlessly
var event = events.findById(eventId);
trace("Event created in system: " + event._createdAt);  // When record was created
trace("Event starts: " + event.startDate);              // When event starts
trace("Event ends: " + event.endDate);                  // When event ends
trace("Last modified: " + event._updatedAt);            // When record was last changed

// Query with custom date fields
var upcomingEvents = events.find({
    startDate: {_gt: Date.now()}  // Events that haven't started yet
});

// Combine automatic and custom dates in queries
var recentlyAddedFutureEvents = events.find({
    _createdAt: {_gte: yesterday},    // Added to system recently
    startDate: {_gt: Date.now()}      // But happening in the future
});
```

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
});
```

#### immediateTransaction()

```haxe
public function immediateTransaction(fn: () -> Void): Void
```

Use immediate transactions when you need to **read data within the transaction** to make decisions. Immediate transactions acquire an exclusive write lock immediately, ensuring that no other transactions can read or write data until completion.

**Key rule**: If your transaction reads data to make decisions, use `immediateTransaction()`.

```haxe
// Good use case: Read-then-write operations
db.immediateTransaction(function() {
    var account = accounts.findById(accountId);
    if (account.balance >= 100) {
        accounts.updateById(accountId, {
            balance: account.balance - 100
        });
        transactions.insert({
            accountId: accountId,
            amount: -100
        });
    }
});
```

#### close()

```haxe
public function close(): Void
```

Closes the database connection.

### Collection Operations

#### insert()

```haxe
public function insert(doc: Document): Int
```

Inserts a new document and returns its ID. Automatically sets `_id`, `_createdAt`, and `_updatedAt`.

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

// Find recent documents using automatic timestamp
var recentDocs = users.find({
    _createdAt: {_gte: yesterday}
});

// Find stale documents
var staleDocs = users.find({
    _updatedAt: {_lt: thirtyDaysAgo}
});

// Find with options
var newest = users.find(
    {active: true},
    {
        orderBy: "_createdAt DESC",  // Use automatic timestamp
        limit: 10
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
    trace("User " + user.name + " created: " + user._createdAt);
}
```

#### findById()

```haxe
public function findById(id: Int): Null<Document>
```

Finds a document by its `_id` field.

#### update()

```haxe
public function update(query: Query, updates: Document): Int
```

Updates all documents matching the query. Returns count of updated documents. Automatically updates `_updatedAt` for all modified documents.

```haxe
// Update documents
var updated = users.update(
    {status: "pending"},
    {status: "approved"}
);
trace("Updated " + updated + " records");
```

#### updateById()

```haxe
public function updateById(id: Int, updates: Document): Bool
```

Updates a single document by ID. Automatically updates `_updatedAt`.

```haxe
users.updateById(userId, {
    lastLogin: Date.now(),
    loginCount: user.loginCount + 1
});
```

#### upsert()

```haxe
public function upsert(doc: Document): Int
```

Atomically inserts a document if it doesn't exist, or updates it if it does exist. If the document has an `_id` field, it will update that document; otherwise, it will insert a new document. Returns the ID of the document (existing ID if updated, new ID if inserted). The operation uses transactions internally to ensure atomicity and prevent race conditions.

```haxe
// Insert new user (no _id field)
var userId = users.upsert({
    email: "alice@example.com",
    name: "Alice Johnson",
    active: true
});

// Update existing user (include _id field)
users.upsert({
    _id: userId,
    email: "alice@example.com",
    name: "Alice Smith",  // Updated name
    active: true,
    lastSeen: Date.now()
});

// If you specify a non-existent _id, it inserts a new document
var newId = users.upsert({
    _id: 99999,  // Non-existent ID
    name: "Bob",
    email: "bob@example.com"
});
// newId will be a new auto-generated ID, not 99999
```

#### delete()

```haxe
public function delete(query: Query): Int
```

Deletes all documents matching the query.

```haxe
// Delete old inactive users
var deleted = users.delete({
    status: "inactive",
    _updatedAt: {_lt: thirtyDaysAgo}  // Not modified in 30 days
});
```

#### deleteById()

```haxe
public function deleteById(id: Int): Bool
```

Deletes a document by ID.

#### count()

```haxe
public function count(?query: Query): Int
```

Counts documents matching the query.

```haxe
var total = users.count();
var active = users.count({active: true});
var recentCount = users.count({
    _createdAt: {_gte: oneDayAgo}  // Created in last 24 hours
});
```

#### createIndex() / dropIndex()

```haxe
public function createIndex(index: IndexDef): Void
public function dropIndex(indexName: String): Void
```

Manages indexes for the collection. Note that `_createdAt` and `_updatedAt` are automatically indexed - no need to create indexes for these fields.

```haxe
// Index on email
users.createIndex({
    name: "idx_email",
    fields: ["email"],
    unique: true
});

// Index on custom date field (not needed for _createdAt/_updatedAt)
events.createIndex({
    name: "idx_event_date",
    fields: ["eventDate"]
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
users.find({_createdAt: {_gte: yesterday}});
users.find({_updatedAt: {_lt: oneWeekAgo}});
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
users.find({deletedAt: {_exists: false}});
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
// Find users who are new OR recently active
users.find({
    _or: [
        {_createdAt: {_gte: oneDayAgo}},     // New users
        {_updatedAt: {_gte: oneHourAgo}}     // Recently active
    ]
});
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
            loginCount: 0
        });
    }

    public function login(username: String, password: String): Null<String> {
        var sessionId: String = null;

        db.immediateTransaction(function() {
            var user = users.findOne({
                username: username,
                password: haxe.crypto.Sha256.encode(password),
                active: true
            });

            if (user == null) return null;

            // Update login info
            users.updateById(user._id, {
                lastLogin: Date.now(),
                loginCount: user.loginCount + 1
            });

            // Create session
            var sessionId = generateSessionId();
            sessions.insert({
                sessionId: sessionId,
                userId: user._id,
                expiresAt: Date.fromTime(Date.now().getTime() + 86400000) // 24 hours
            });
        });

        return sessionId;
    }

    public function getRecentUsers(hours: Int = 24) {
        var since = Date.fromTime(Date.now().getTime() - (hours * 3600000));
        return users.find(
            {_createdAt: {_gte: since}},
            {orderBy: "_createdAt DESC"}
        );
    }

    public function findInactiveUsers(days: Int) {
        var cutoff = Date.fromTime(Date.now().getTime() - (days * 86400000));

        // Users who haven't been updated (no login, no profile changes, etc.)
        return users.find({_updatedAt: {_lt: cutoff}});
    }

    public function cleanupExpiredSessions() {
        var now = Date.now();

        // Delete expired sessions
        var deleted = sessions.delete({expiresAt: {_lt: now}});

        // Also delete very old sessions (created > 30 days ago)
        var thirtyDaysAgo = Date.fromTime(now.getTime() - 2592000000);
        deleted += sessions.delete({_createdAt: {_lt: thirtyDaysAgo}});

        return deleted;
    }
}
```

### Content Management System

```haxe
class ContentManager {
    var db: Jimjam;
    var posts: Collection;
    var comments: Collection;

    public function new() {
        db = new Jimjam("cms.db");
        posts = db.collection("posts");
        comments = db.collection("comments");
    }

    public function createPost(title: String, content: String, authorId: Int) {
        return posts.insert({
            title: title,
            content: content,
            authorId: authorId,
            status: "draft",
            views: 0
        });
    }

    public function publishPost(postId: Int) {
        posts.updateById(postId, {
            status: "published",
            publishedDate: Date.now()
        });
    }

    public function getRecentPosts(limit: Int = 10) {
        return posts.find(
            {status: "published"},
            {
                orderBy: "_createdAt DESC",
                limit: limit
            }
        );
    }

    public function getRecentlyEditedDrafts() {
        var oneDayAgo = Date.fromTime(Date.now().getTime() - 86400000);

        return posts.find({
            status: "draft",
            _updatedAt: {_gte: oneDayAgo}
        });
    }

    public function addComment(postId: Int, authorId: Int, text: String) {
        db.transaction(function() {
            comments.insert({
                postId: postId,
                authorId: authorId,
                text: text
            });

            var post = posts.findById(postId);
            posts.updateById(postId, {
                commentCount: (post.commentCount ?? 0) + 1
            });
        });
    }

    public function getPostActivity(postId: Int, days: Int = 7) {
        var since = Date.fromTime(Date.now().getTime() - (days * 86400000));

        return comments.find(
            {
                postId: postId,
                _createdAt: {_gte: since}
            },
            {orderBy: "_createdAt DESC"}
        );
    }

    public function archiveOldDrafts(days: Int = 90) {
        var cutoff = Date.fromTime(Date.now().getTime() - (days * 86400000));

        return posts.update(
            {
                status: "draft",
                _updatedAt: {_lt: cutoff}
            },
            {status: "archived"}
        );
    }
}
```

### Analytics and Metrics

```haxe
class Analytics {
    var db: Jimjam;
    var pageViews: Collection;
    var events: Collection;

    public function new() {
        db = new Jimjam("analytics.db");
        pageViews = db.collection("page_views");
        events = db.collection("events");
    }

    public function trackPageView(url: String, userId: Null<Int>, referrer: String) {
        pageViews.insert({
            url: url,
            userId: userId,
            referrer: referrer,
            userAgent: getUserAgent()
        });
    }

    public function trackEvent(eventName: String, userId: Null<Int>, data: Dynamic) {
        events.insert({
            name: eventName,
            userId: userId,
            data: data
        });
    }

    public function getRealtimeUsers(minutes: Int = 5) {
        var since = Date.fromTime(Date.now().getTime() - (minutes * 60000));

        // Count unique users active in last X minutes
        var recentViews = pageViews.find({_createdAt: {_gte: since}});

        var uniqueUsers = new Map<Int, Bool>();
        for (view in recentViews) {
            if (view.userId != null) {
                uniqueUsers.set(view.userId, true);
            }
        }

        return uniqueUsers.keys().count();
    }

    public function getHourlyStats(hours: Int = 24) {
        var stats = [];
        var now = Date.now().getTime();

        for (i in 0...hours) {
            var hourStart = Date.fromTime(now - ((i + 1) * 3600000));
            var hourEnd = Date.fromTime(now - (i * 3600000));

            var views = pageViews.count({
                _createdAt: {_gte: hourStart, _lt: hourEnd}
            });

            var events = events.count({
                _createdAt: {_gte: hourStart, _lt: hourEnd}
            });

            stats.push({
                hour: hourStart,
                views: views,
                events: events
            });
        }

        return stats;
    }

    public function getDailyActiveUsers(date: Date) {
        var dayStart = Date.fromTime(Math.floor(date.getTime() / 86400000) * 86400000);
        var dayEnd = Date.fromTime(dayStart.getTime() + 86400000);

        var dayViews = pageViews.find({
            _createdAt: {_gte: dayStart, _lt: dayEnd}
        });

        var uniqueUsers = new Map<Int, Bool>();
        for (view in dayViews) {
            if (view.userId != null) {
                uniqueUsers.set(view.userId, true);
            }
        }

        return uniqueUsers.keys().count();
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
    name: "Widget",          // Text
    price: 29.99,            // Float
    quantity: 100,           // Int
    inStock: true,           // Bool
    specs: {                 // Complex object (JSON)
        color: "blue",
        size: "medium"
    }
});

// Types are preserved when reading
var product = products.findOne({name: "Widget"});
trace(product.price);        // 29.99 (Float)
trace(product.inStock);      // true (Bool)
trace(product._createdAt);   // Date object
trace(product.specs.color);  // "blue"
```

### Field Types

Jimjam supports the following field types:

- **Float**: Integer numbers
- **Int**: Floating-point numbers
- **String**: String values
- **Bool**: Boolean values
- **Json**: Complex objects and arrays, automatically serialized as JSON
- **Date**: `Date` objects (stored as UTC timestamps)

The automatic timestamp fields (`_createdAt` and `_updatedAt`) are always stored as FTText in SQLite but are automatically converted to/from Date objects.

### Automatic Type Upgrades

When a Float value is assigned to an Integer field, it automatically upgrades:

```haxe
// Initially integer
products.insert({productId: 1, rating: 4});

// Later update with float - type upgrades
products.update({productId: 1}, {rating: 4.5});

// Future inserts treat rating as float too
products.insert({productId: 2, rating: 5}); // Stored as 5.0
```

## Best Practices

### 1. Leverage Automatic Timestamps

```haxe
// DON'T do this:
users.insert({
    name: "John",
    createdAt: Date.now(),      // Redundant!
    registeredAt: Date.now(),   // Redundant!
    joinedAt: Date.now()        // Redundant!
});

// DO this instead:
users.insert({
    name: "John"
    // _createdAt is automatic and serves all these purposes
});

// Then query using the automatic field:
var newUsers = users.find({_createdAt: {_gte: yesterday}});
```

### 2. Use _updatedAt for Activity Tracking

```haxe
// DON'T track activity manually:
users.updateById(userId, {
    lastActivity: Date.now(),  // Redundant!
    lastModified: Date.now()   // Redundant!
});

// DO use the automatic _updatedAt:
users.updateById(userId, {
    // Any update automatically refreshes _updatedAt
    lastAction: "viewed_profile"
});

// Find recently active users:
var activeUsers = users.find({_updatedAt: {_gte: oneHourAgo}});
```

### 3. Choose the Right Transaction Type

```haxe
// For simple coordinated writes (no reads):
db.transaction(function() {
    var userId = users.insert({name: "John"});
    profiles.insert({userId: userId, bio: "Hello!"});
});

// For read-then-write operations:
db.immediateTransaction(function() {
    var stats = statistics.findOne({});
    statistics.update({}, {
        userCount: stats.userCount + 1
    });
});
```

### 4. Create Appropriate Indexes

```haxe
// Note: _createdAt and _updatedAt are automatically indexed!
// No need to create indexes for these timestamp fields

// Only create indexes for your custom fields
users.createIndex({
    name: "idx_email",
    fields: ["email"],
    unique: true
});

// Index custom date fields if needed
events.createIndex({
    name: "idx_start_date",
    fields: ["startDate"]  // Custom event date
});
```

### 5. Use Custom Date Fields Only When Needed

```haxe
// Use automatic timestamps when possible:
var post = posts.insert({
    title: "My Post",
    content: "..."
});
// _createdAt = when post was created
// _updatedAt = when post was last edited

// Add custom dates only for domain-specific needs:
var event = events.insert({
    name: "Conference",
    startDate: futureDate,          // When event happens
    endDate: futureEndDate,         // When event ends
    registrationDeadline: deadline  // Domain-specific deadline
});
// _createdAt = when event was added to system
// _updatedAt = when event details last changed
```

## Performance Tips

### 1. Use Automatic Timestamps in Queries

```haxe
// Fast: automatic timestamps are already indexed!
var recent = posts.find({_createdAt: {_gte: yesterday}});

// Slower: custom field might not be indexed
var recent = posts.find({customTimestamp: {_gte: yesterday}});
```

### 2. Batch Operations in Transactions

```haxe
db.transaction(function() {
    for (i in 0...10000) {
        items.insert({
            index: i,
            value: Math.random()
            // Automatic timestamps for all!
        });
    }
});
```

### 3. Optimize Time-Based Queries

```haxe
// Automatic timestamps are already indexed for efficient queries!
var todayStart = Date.fromTime(Math.floor(Date.now().getTime() / 86400000) * 86400000);
var todaysDocs = collection.find({
    _createdAt: {_gte: todayStart}
});

// For custom date fields, create indexes as needed
events.createIndex({
    name: "idx_date_range",
    fields: ["startDate", "endDate"]
});
```

### 4. Monitor Data Freshness

```haxe
// Find stale data that hasn't been updated
var staleData = collection.find({
    _updatedAt: {_lt: thirtyDaysAgo},
    status: "active"
});

// Archive old, unmodified records
var archived = collection.update(
    {_updatedAt: {_lt: ninetyDaysAgo}},
    {status: "archived"}
);
```