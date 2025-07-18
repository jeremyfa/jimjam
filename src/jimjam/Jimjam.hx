package jimjam;

import haxe.Json;
import sys.db.Connection;
import sys.db.ResultSet;
import sys.db.Sqlite;

using StringTools;

typedef Document = {
    ?_id: String,
    ?_createdAt: Date,
    ?_updatedAt: Date
}
typedef Query = Dynamic;
typedef IndexDef = {
    name: String,
    fields: Array<String>,
    ?unique: Bool
}

enum FieldType {
    FTInteger;
    FTFloat;
    FTText;
    FTBoolean;
    FTJson;
    FTDate;
}

/**
 * MongoDB-style query operators for advanced querying
 * Uses underscore prefix to avoid conflicts with Haxe string interpolation
 */
enum abstract QueryOperator(String) to String {
    var GT = "_gt";      // Greater than
    var GTE = "_gte";    // Greater than or equal
    var LT = "_lt";      // Less than
    var LTE = "_lte";    // Less than or equal
    var NE = "_ne";      // Not equal
    var IN = "_in";      // In array
    var NIN = "_nin";    // Not in array
    var EXISTS = "_exists"; // Field exists
    var REGEX = "_regex";   // Regular expression
    var OR = "_or";      // Logical OR
    var AND = "_and";    // Logical AND
    var NOT = "_not";    // Logical NOT
}

/**
 * Jimjam - A flexible NoSQL-style database built on SQLite
 *
 * Main database class that manages connections and collections
 */
class Jimjam {
    public var connection: Connection;
    private var collections: Map<String, Collection<Dynamic>>;
    public var inTransaction: Bool = false;
    private var dbPath: String;

    /**
     * Creates a new Jimjam database instance
     *
     * @param dbPath Path to the SQLite database file
     *
     * @example
     * ```haxe
     * var db = new Jimjam("myapp.db");
     * var users = db.collection("users");
     * var orders = db.collection("orders");
     * ```
     */
    public function new(dbPath: String) {
        this.dbPath = dbPath;
        this.connection = Sqlite.open(dbPath);
        this.collections = new Map();

        // Enable foreign keys
        connection.request("PRAGMA foreign_keys = ON");
    }

    /**
     * Gets or creates a collection (table) with optional type safety
     *
     * @param name The collection name
     * @return The collection instance
     *
     * @example
     * ```haxe
     * // Dynamic collection (default)
     * var users = db.collection("users");
     *
     * // Typed collection
     * typedef User = {>Document, name: String, email: String}
     * var users:Collection<User> = cast db.collection("users");
     * ```
     */
    public extern inline overload function collection(name: String): Collection {
        if (!collections.exists(name)) {
            collections.set(name, cast new Collection(connection, name, this));
        }
        return cast collections.get(name);
    }

    /**
     * Executes a SQLite PRAGMA command
     *
     * @param pragmaCommand The pragma command (without PRAGMA prefix)
     * @return The result set from the pragma command
     *
     * @example
     * ```haxe
     * db.pragma("busy_timeout = 5000");
     * db.pragma("journal_mode = WAL");
     * var cacheSize = db.pragma("cache_size");
     * ```
     */
    public function pragma(pragmaCommand: String): ResultSet {
        return connection.request("PRAGMA " + pragmaCommand);
    }

    /**
     * Begins a database transaction
     * All operations on all collections will be part of this transaction
     *
     * @throws String if a transaction is already in progress
     *
     * @example
     * ```haxe
     * db.beginTransaction();
     * try {
     *     users.insert({name: "John"});
     *     orders.insert({userId: 1, total: 99.99});
     *     db.commit();
     * } catch (e: Dynamic) {
     *     db.rollback();
     * }
     * ```
     */
    public function beginTransaction(): Void {
        if (inTransaction) {
            throw "Transaction already in progress";
        }
        connection.request("BEGIN TRANSACTION");
        inTransaction = true;
    }

    /**
     * Begins an immediate database transaction
     * Acquires a write lock immediately, preventing other writers
     *
     * @throws String if a transaction is already in progress
     *
     * @example
     * ```haxe
     * db.beginImmediateTransaction();
     * try {
     *     var user = users.findById(1);
     *     var account = accounts.findById(user.accountId);
     *     // Both reads are guaranteed to see consistent data
     *     db.commit();
     * } catch (e: Dynamic) {
     *     db.rollback();
     * }
     * ```
     */
    public function beginImmediateTransaction(): Void {
        if (inTransaction) {
            throw "Transaction already in progress";
        }
        connection.request("BEGIN IMMEDIATE TRANSACTION");
        inTransaction = true;
    }

    /**
     * Commits the current transaction
     *
     * @throws String if no transaction is in progress
     */
    public function commit(): Void {
        if (!inTransaction) {
            throw "No transaction in progress";
        }
        connection.request("COMMIT");
        inTransaction = false;
    }

    /**
     * Rolls back the current transaction
     *
     * @throws String if no transaction is in progress
     */
    public function rollback(): Void {
        if (!inTransaction) {
            throw "No transaction in progress";
        }
        connection.request("ROLLBACK");
        inTransaction = false;
    }

    /**
     * Executes a function within a transaction
     * Automatically commits on success or rolls back on error
     *
     * @param fn The function to execute within the transaction
     *
     * @example
     * ```haxe
     * var result = db.transaction(function() {
     *     var userId = users.insert({name: "John"});
     *     var orderId = orders.insert({userId: userId});
     *     return {userId: userId, orderId: orderId};
     * });
     * ```
     */
    public function transaction(fn: ()->Void): Void {
        beginTransaction();
        try {
            fn();
            commit();
        } catch (e: Dynamic) {
            rollback();
            throw e;
        }
    }

    /**
     * Executes a function within an immediate transaction
     * Automatically commits on success or rolls back on error
     * Acquires write lock immediately for stronger isolation
     *
     * @param fn The function to execute within the transaction
     *
     * @example
     * ```haxe
     * db.immediateTransaction(function() {
     *     // All reads see a consistent snapshot
     *     var stats = db.collection("stats").findOne({});
     *     var users = db.collection("users").count();
     *     // Update based on consistent reads
     *     db.collection("stats").update({}, {userCount: users});
     * });
     * ```
     */
    public function immediateTransaction(fn: ()->Void): Void {
        beginImmediateTransaction();
        try {
            fn();
            commit();
        } catch (e: Dynamic) {
            rollback();
            throw e;
        }
    }

    /**
     * Closes the database connection
     */
    public function close(): Void {
        if (inTransaction) {
            rollback();
        }
        connection.close();
    }

    /**
     * Reinitialize the database connection (internal use for C++ target)
     */
    public function reinitializeConnection(): Void {
        #if cpp
        try {
            connection.close();
        } catch (e: Dynamic) {
        }
        connection = Sqlite.open(dbPath);
        // Re-enable foreign keys
        connection.request("PRAGMA foreign_keys = ON");
        #end
    }
}

/**
 * Represents a collection (table) in the database
 * All CRUD operations are performed through collections
 *
 * @param T The document type (defaults to Dynamic for flexibility)
 */
class Collection<T = Dynamic<Dynamic>> {
    private var connection: Connection;
    private var tableName: String;
    private var typeCache: Map<String, FieldType>;
    private var db: Jimjam;

    /**
     * Creates a new collection instance (internal use)
     */
    public function new(connection: Connection, tableName: String, db: Jimjam) {
        this.connection = connection;
        this.tableName = tableName;
        this.db = db;
        this.typeCache = new Map();

        // Initialize tables
        initializeTables();

        // Load existing types
        loadTypeCache();
    }

    /**
     * Converts a Date to UTC string in YYYY-MM-DD HH:MM:SS format
     * Pure Haxe implementation to avoid timezone issues
     */
    private static function dateToUTCString(date: Date): String {
        // Get timestamp in milliseconds
        var timestamp = date.getTime();

        // Calculate total seconds since epoch
        var totalSeconds = Math.floor(timestamp / 1000);

        // Calculate components
        var secondsPerMinute = 60;
        var secondsPerHour = 3600;
        var secondsPerDay = 86400;

        // Days since Unix epoch (1970-01-01)
        var days = Math.floor(totalSeconds / secondsPerDay);
        var remainingSeconds = totalSeconds % secondsPerDay;

        // Time components
        var hours = Math.floor(remainingSeconds / secondsPerHour);
        var minutes = Math.floor((remainingSeconds % secondsPerHour) / secondsPerMinute);
        var seconds = remainingSeconds % secondsPerMinute;

        // Calculate year, month, day
        var year = 1970;
        var month = 1;
        var day = 1;

        // Add days to get actual date
        var daysRemaining = days;

        // Leap year calculation
        function isLeapYear(y: Int): Bool {
            return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
        }

        // Days in month
        function daysInMonth(m: Int, y: Int): Int {
            return switch(m) {
                case 1, 3, 5, 7, 8, 10, 12: 31;
                case 4, 6, 9, 11: 30;
                case 2: isLeapYear(y) ? 29 : 28;
                default: 0;
            }
        }

        // Calculate year
        while (true) {
            var daysInYear = isLeapYear(year) ? 366 : 365;
            if (daysRemaining >= daysInYear) {
                daysRemaining -= daysInYear;
                year++;
            } else {
                break;
            }
        }

        // Calculate month and day
        while (daysRemaining > 0) {
            var daysInCurrentMonth = daysInMonth(month, year);
            if (daysRemaining >= daysInCurrentMonth) {
                daysRemaining -= daysInCurrentMonth;
                month++;
                if (month > 12) {
                    month = 1;
                    year++;
                }
            } else {
                day = daysRemaining + 1;
                break;
            }
        }

        // Format components with padding
        var yearStr = Std.string(year);
        var monthStr = month < 10 ? "0" + month : Std.string(month);
        var dayStr = day < 10 ? "0" + day : Std.string(day);
        var hourStr = hours < 10 ? "0" + hours : Std.string(hours);
        var minuteStr = minutes < 10 ? "0" + minutes : Std.string(minutes);
        var secondStr = seconds < 10 ? "0" + seconds : Std.string(seconds);

        return '$yearStr-$monthStr-$dayStr $hourStr:$minuteStr:$secondStr';
    }

    /**
     * Parses UTC string in YYYY-MM-DD HH:MM:SS format to Date
     * Pure Haxe implementation to avoid timezone issues
     */
    private static function utcStringToDate(str: String): Date {
        // Parse the string
        var parts = str.split(" ");
        if (parts.length != 2) return null;

        var dateParts = parts[0].split("-");
        var timeParts = parts[1].split(":");

        if (dateParts.length != 3 || timeParts.length != 3) return null;

        var year = Std.parseInt(dateParts[0]);
        var month = Std.parseInt(dateParts[1]);
        var day = Std.parseInt(dateParts[2]);
        var hour = Std.parseInt(timeParts[0]);
        var minute = Std.parseInt(timeParts[1]);
        var second = Std.parseInt(timeParts[2]);

        // Validate parsed values
        if (year == null || month == null || day == null ||
            hour == null || minute == null || second == null) {
            return null;
        }

        // Calculate days since epoch
        var totalDays = 0;

        // Add days for complete years
        for (y in 1970...year) {
            totalDays += isLeapYear(y) ? 366 : 365;
        }

        // Add days for complete months in current year
        for (m in 1...month) {
            totalDays += daysInMonth(m, year);
        }

        // Add remaining days
        totalDays += day - 1;

        // Calculate total seconds
        var totalSeconds = totalDays * 86400 + hour * 3600 + minute * 60 + second;

        // Convert to milliseconds and create Date
        return Date.fromTime(totalSeconds * 1000.0);
    }

    // Helper functions for date calculations
    private static function isLeapYear(y: Int): Bool {
        return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    }

    private static function daysInMonth(m: Int, y: Int): Int {
        return switch(m) {
            case 1, 3, 5, 7, 8, 10, 12: 31;
            case 4, 6, 9, 11: 30;
            case 2: isLeapYear(y) ? 29 : 28;
            default: 0;
        }
    }

    /**
     * Initializes the collection tables and triggers
     */
    private function initializeTables(): Void {
        // Main document table
        var sql = 'CREATE TABLE IF NOT EXISTS $tableName (
            _id INTEGER PRIMARY KEY AUTOINCREMENT,
            _createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
            _updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
        )';
        executeQuery(sql);

        // Type metadata table
        var typeTableSql = 'CREATE TABLE IF NOT EXISTS ${tableName}_types (
            field_name TEXT PRIMARY KEY,
            field_type TEXT NOT NULL
        )';
        executeQuery(typeTableSql);

        // Index metadata table
        var indexTableSql = 'CREATE TABLE IF NOT EXISTS ${tableName}_indexes (
            index_name TEXT PRIMARY KEY,
            field_names TEXT NOT NULL,
            is_unique INTEGER NOT NULL DEFAULT 0
        )';
        executeQuery(indexTableSql);

        // Create trigger for updated_at
        var triggerSql = 'CREATE TRIGGER IF NOT EXISTS update_${tableName}_timestamp
            AFTER UPDATE ON $tableName
            BEGIN
                UPDATE $tableName SET _updatedAt = CURRENT_TIMESTAMP WHERE _id = NEW._id;
            END';
        executeQuery(triggerSql);

        // Ensure built-in columns are in the types table
        var builtinFields = [
            {name: "_id", type: "INTEGER"},
            {name: "_createdAt", type: "TEXT"},
            {name: "_updatedAt", type: "TEXT"}
        ];

        for (field in builtinFields) {
            var typeSql = 'INSERT OR IGNORE INTO ${tableName}_types (field_name, field_type) VALUES (?, ?)';
            executeQuery(typeSql, [field.name, field.type]);
        }

        // Create automatic indexes for timestamp fields
        createAutomaticIndexes();
    }

    /**
     * Creates automatic indexes for built-in timestamp fields
     */
    private function createAutomaticIndexes(): Void {
        // Create index for _createdAt if it doesn't exist
        var createdAtIndexName = 'idx_${tableName}_created';
        try {
            var sql = 'CREATE INDEX IF NOT EXISTS $createdAtIndexName ON $tableName (_createdAt)';
            executeDDL(sql);

            // Store index metadata
            var indexSql = 'INSERT OR IGNORE INTO ${tableName}_indexes (index_name, field_names, is_unique) VALUES (?, ?, ?)';
            executeDDL(indexSql, [createdAtIndexName, '["_createdAt"]', 0]);
        } catch (e: Dynamic) {
            // Index might already exist, ignore error
        }

        // Create index for _updatedAt if it doesn't exist
        var updatedAtIndexName = 'idx_${tableName}_updated';
        try {
            var sql = 'CREATE INDEX IF NOT EXISTS $updatedAtIndexName ON $tableName (_updatedAt)';
            executeDDL(sql);

            // Store index metadata
            var indexSql = 'INSERT OR IGNORE INTO ${tableName}_indexes (index_name, field_names, is_unique) VALUES (?, ?, ?)';
            executeDDL(indexSql, [updatedAtIndexName, '["_updatedAt"]', 0]);
        } catch (e: Dynamic) {
            // Index might already exist, ignore error
        }
    }


    /**
     * Loads the field type metadata into memory cache
     */
    private function loadTypeCache(): Void {
        try {
            var result = executeQuery('SELECT field_name, field_type FROM ${tableName}_types');
            // Process all rows immediately to avoid ResultSet finalization issues
            var rows = [];
            while (result.hasNext()) {
                rows.push(result.next());
            }

            for (row in rows) {
                typeCache.set(row.field_name, parseFieldType(row.field_type));
            }
        } catch (e: Dynamic) {
            // If type cache loading fails, continue with empty cache
            // This allows the system to work even if type metadata is missing
        }
    }

    /**
     * Parses a string representation of a field type into the FieldType enum
     */
    private function parseFieldType(typeStr: String): FieldType {
        return switch (typeStr) {
            case "INTEGER": FTInteger;
            case "FLOAT": FTFloat;
            case "TEXT": FTText;
            case "BOOLEAN": FTBoolean;
            case "JSON": FTJson;
            case "DATE": FTDate;
            default: FTText;
        };
    }

    /**
     * Converts a FieldType enum to its string representation
     */
    private function fieldTypeToString(type: FieldType): String {
        return switch (type) {
            case FTInteger: "INTEGER";
            case FTFloat: "FLOAT";
            case FTText: "TEXT";
            case FTBoolean: "BOOLEAN";
            case FTJson: "JSON";
            case FTDate: "DATE";
        };
    }

    /**
     * Detects the field type of a value
     */
    private function detectFieldType(value: Dynamic): FieldType {
        if (value == null) return FTText;

        // Check if it's a Date object
        if (Std.isOfType(value, Date)) {
            return FTDate;
        }

        switch (Type.typeof(value)) {
            case TInt: return FTInteger;
            case TFloat: return FTFloat;
            case TBool: return FTBoolean;
            case TObject, TClass(_):
                if (Std.isOfType(value, String)) {
                    return FTText;
                } else {
                    return FTJson;
                }
            default: return FTText;
        }
    }

    /**
     * Maps FieldType to SQLite column types
     */
    private function getSqliteType(fieldType: FieldType): String {
        return switch (fieldType) {
            case FTInteger: "INTEGER";
            case FTFloat: "REAL";
            case FTBoolean: "INTEGER";
            case FTText, FTJson, FTDate: "TEXT";
        };
    }


    /**
     * Gets all field names from a document
     */
    private function getDocumentFields(doc: Dynamic): Array<String> {
        return Reflect.fields(doc);
    }

    /**
     * Gets a field value from a document
     */
    private function getDocumentField(doc: Dynamic, field: String): Dynamic {
        return Reflect.field(doc, field);
    }

    /**
     * Sets a field value in a document
     */
    private function setDocumentField(doc: Dynamic, field: String, value: Dynamic): Void {
        Reflect.setField(doc, field, value);
    }

    /**
     * Ensures all fields in the document have corresponding columns
     */
    private function ensureColumns(doc: Dynamic): Void {
        var newColumns = [];
        var typeUpgrades = [];

        for (field in getDocumentFields(doc)) {
            var value = getDocumentField(doc, field);
            var detectedType = detectFieldType(value);

            if (!typeCache.exists(field)) {
                // New column
                var sqlType = getSqliteType(detectedType);
                newColumns.push({field: field, sqlType: sqlType, fieldType: detectedType});
            } else {
                // Check if we need to upgrade the type
                var cachedType = typeCache.get(field);
                if (cachedType != null && shouldUpgradeType(cachedType, detectedType)) {
                    typeUpgrades.push({field: field, newType: detectedType});
                }
            }
        }

        // Add new columns
        for (col in newColumns) {
            try {
                var sql = 'ALTER TABLE $tableName ADD COLUMN ${escapeFieldName(col.field)} ${col.sqlType}';
                executeDDL(sql);

                var typeSql = 'INSERT OR REPLACE INTO ${tableName}_types (field_name, field_type) VALUES (?, ?)';
                executeDDL(typeSql, [col.field, fieldTypeToString(col.fieldType)]);
                typeCache.set(col.field, col.fieldType);
            } catch (e: Dynamic) {
                // Column might already exist, reload type cache
                loadTypeCache();
            }
        }

        // Upgrade field types (with index rebuilding)
        for (upgrade in typeUpgrades) {
            upgradeFieldType(upgrade.field, upgrade.newType);
        }
    }

    /**
     * Executes a DDL/DML statement that doesn't return data
     */
    private function executeDDL(sql: String, ?params: Array<Dynamic>): Void {
        var finalSql = sql;

        // Handle parameterized queries
        if (params != null && params.length > 0) {
            var paramIndex = 0;

            // Replace parameters one by one to avoid replacing all ? with the same value
            while (finalSql.indexOf('?') != -1 && paramIndex < params.length) {
                var param = params[paramIndex];
                var escapedParam = param == null ? 'NULL' : connection.quote(Std.string(param));

                // Replace only the first occurrence of '?'
                var questionPos = finalSql.indexOf('?');
                finalSql = finalSql.substring(0, questionPos) + escapedParam + finalSql.substring(questionPos + 1);
                paramIndex++;
            }
        }


        // Execute the DDL statement
        try {
            var result = connection.request(finalSql);

            /*#if cpp
            // C++ target needs ResultSet consumption to avoid "Could not finalize request" errors
            while (result.hasNext()) {
                result.next();
            }
            #else*/
            // PHP target: DDL statements work fine without consuming ResultSet
            //#end

        } catch (e: Dynamic) {

            #if cpp
            // C++ target: Check for "Could not finalize request" error and recreate connection
            // Only do this if we're not inside a transaction
            if (!db.inTransaction && Std.string(e).indexOf("Could not finalize request") != -1) {

                try {
                    // Use Jimjam's connection recovery method
                    db.reinitializeConnection();

                    // Update our local connection reference
                    connection = db.connection;

                    // Retry the DDL operation
                    var result = connection.request(finalSql);
                    return;
                } catch (retryError: Dynamic) {
                    throw retryError;
                }
            }
            #end

            throw e;
        }
    }

    /**
     * Executes a parameterized query that returns data
     */
    private function executeQuery(sql: String, ?params: Array<Dynamic>): ResultSet {
        var finalSql = sql;

        // Handle parameterized queries
        if (params != null && params.length > 0) {
            var paramIndex = 0;

            // Replace parameters one by one to avoid replacing all ? with the same value
            while (finalSql.indexOf('?') != -1 && paramIndex < params.length) {
                var param = params[paramIndex];
                var escapedParam = param == null ? 'NULL' : connection.quote(Std.string(param));

                // Replace only the first occurrence of '?'
                var questionPos = finalSql.indexOf('?');
                finalSql = finalSql.substring(0, questionPos) + escapedParam + finalSql.substring(questionPos + 1);
                paramIndex++;
            }
        }

        // Execute the query and return the ResultSet
        return connection.request(finalSql);
    }

    /**
     * Gets the number of affected rows for the last operation
     */
    private function getChanges(): Int {
        try {
            var result = executeQuery("SELECT changes()");
            var rows = [];
            while (result.hasNext()) {
                rows.push(result.next());
            }

            if (rows.length > 0) {
                var row = rows[0];
                return Reflect.field(row, "changes()");
            }
        } catch (e: Dynamic) {
            // If changes() fails, return 0
        }
        return 0;
    }

    /**
     * Escapes field names to handle SQL reserved keywords
     */
    private function escapeFieldName(fieldName: String): String {
        // List of common SQL reserved keywords that might be used as field names
        var reservedWords = ["from", "to", "select", "where", "order", "group", "having", "limit", "offset", "join", "on", "as", "in", "not", "and", "or", "like", "between", "exists", "union", "insert", "update", "delete", "create", "drop", "alter", "table", "index"];

        if (reservedWords.indexOf(fieldName.toLowerCase()) != -1) {
            return '"' + fieldName + '"';
        }
        return fieldName;
    }

    /**
     * Gets all indexes that include a specific field
     */
    private function getIndexesForField(fieldName: String): Array<String> {
        var indexNames = [];

        try {
            var result = executeQuery('SELECT index_name, field_names FROM ${tableName}_indexes');
            var rows = [];
            while (result.hasNext()) {
                rows.push(result.next());
            }

            for (row in rows) {
                var indexName = row.index_name;
                var fieldNamesJson = row.field_names;

                try {
                    var fieldNames: Array<String> = haxe.Json.parse(fieldNamesJson);
                    if (fieldNames.indexOf(fieldName) != -1) {
                        indexNames.push(indexName);
                    }
                } catch (e: Dynamic) {
                    // Skip malformed index metadata
                }
            }
        } catch (e: Dynamic) {
            // If query fails, return empty array
        }

        return indexNames;
    }

    /**
     * Gets the definition of an index for rebuilding
     */
    private function getIndexDefinition(indexName: String): IndexDef {
        var fields = [];
        var isUnique = false;

        try {
            var result = executeQuery('SELECT field_names, is_unique FROM ${tableName}_indexes WHERE index_name = ?', [indexName]);

            var rows = [];
            while (result.hasNext()) {
                rows.push(result.next());
            }

            if (rows.length > 0) {
                var row = rows[0];
                var fieldNamesJson = row.field_names;
                isUnique = row.is_unique == 1;

                try {
                    fields = haxe.Json.parse(fieldNamesJson);
                } catch (e: Dynamic) {
                    fields = [];
                }
            }
        } catch (e: Dynamic) {
            // If we can't find the index, return empty definition
        }

        return {
            name: indexName,
            fields: fields,
            unique: isUnique
        };
    }

    /**
     * Determines if one field type is more specific than another
     */
    private function shouldUpgradeType(cachedType: FieldType, detectedType: FieldType): Bool {
        // TEXT is the least specific type and can be upgraded to any other type
        if (cachedType == FTText && detectedType != FTText) {
            return true;
        }

        // INTEGER can be upgraded to REAL for numeric precision
        if (cachedType == FTInteger && detectedType == FTFloat) {
            return true;
        }

        // No other upgrades are allowed
        return false;
    }

    /**
     * Upgrades a field type and rebuilds any affected indexes
     */
    private function upgradeFieldType(field: String, newType: FieldType): Void {
        // 1. Get all indexes that include this field
        var affectedIndexes = getIndexesForField(field);

        // 2. Store index definitions for rebuilding
        var indexDefs = [];
        for (indexName in affectedIndexes) {
            indexDefs.push(getIndexDefinition(indexName));
        }

        // 3. Drop affected indexes
        for (indexName in affectedIndexes) {
            dropIndex(indexName);
        }

        // 4. Update type metadata in database
        var typeSql = 'UPDATE ${tableName}_types SET field_type = ? WHERE field_name = ?';
        executeQuery(typeSql, [fieldTypeToString(newType), field]);

        // 5. Update type cache
        typeCache.set(field, newType);

        // 6. Recreate indexes with new type
        for (indexDef in indexDefs) {
            createIndex(indexDef);
        }
    }

    /**
     * Serializes a value for storage
     */
    private function serializeValue(field: String, value: Dynamic): Dynamic {
        if (value == null) return null;

        var fieldType = typeCache.get(field);
        if (fieldType == null) {
            fieldType = detectFieldType(value);
        }

        return switch (fieldType) {
            case FTBoolean: value ? 1 : 0;
            case FTJson: Json.stringify(value);
            case FTDate:
                if (Std.isOfType(value, Date)) {
                    dateToUTCString(cast value);
                } else {
                    value;
                }
            case FTInteger, FTFloat: value;
            default: value;
        };
    }

    /**
     * Deserializes a value from storage
     */
    private function deserializeValue(field: String, value: Dynamic): Dynamic {
        if (value == null) return null;

        var fieldType = typeCache.get(field);
        if (fieldType == null) return value;

        return switch (fieldType) {
            case FTBoolean: value == 1;
            case FTJson:
                try {
                    Json.parse(value);
                } catch (e: Dynamic) {
                    value;
                }
            case FTDate:
                if (Std.isOfType(value, String)) {
                    utcStringToDate(value);
                } else {
                    value;
                }
            case FTInteger: Std.int(value);
            case FTFloat: value;
            default: value;
        };
    }

    /**
     * Parses query conditions for a single field
     */
    private function parseQueryCondition(field: String, condition: Dynamic, params: Array<Dynamic>): String {
        // If field doesn't exist in type cache, the column doesn't exist
        // This provides NoSQL-like behavior where querying non-existent fields returns no results
        if (!typeCache.exists(field)) {
            return '1=0';
        }

        var escapedField = escapeFieldName(field);
        if (condition == null) {
            params.push(null);
            return '$escapedField IS ?';
        }

        if (Reflect.isObject(condition) && !Std.isOfType(condition, String)) {
            var conditions = [];

            for (op in Reflect.fields(condition)) {
                var value:Dynamic = Reflect.field(condition, op);

                switch (op) {
                    case QueryOperator.GT:
                        params.push(serializeValue(field, value));
                        conditions.push('$escapedField > ?');

                    case QueryOperator.GTE:
                        params.push(serializeValue(field, value));
                        conditions.push('$escapedField >= ?');

                    case QueryOperator.LT:
                        params.push(serializeValue(field, value));
                        conditions.push('$escapedField < ?');

                    case QueryOperator.LTE:
                        params.push(serializeValue(field, value));
                        conditions.push('$escapedField <= ?');

                    case QueryOperator.NE:
                        params.push(serializeValue(field, value));
                        conditions.push('$escapedField != ?');

                    case QueryOperator.IN:
                        if (Std.isOfType(value, Array)) {
                            var arr: Array<Dynamic> = cast value;
                            var placeholders = [];
                            for (v in arr) {
                                params.push(serializeValue(field, v));
                                placeholders.push('?');
                            }
                            conditions.push('$escapedField IN (${placeholders.join(", ")})');
                        }

                    case QueryOperator.NIN:
                        if (Std.isOfType(value, Array)) {
                            var arr: Array<Dynamic> = cast value;
                            var placeholders = [];
                            for (v in arr) {
                                params.push(serializeValue(field, v));
                                placeholders.push('?');
                            }
                            conditions.push('$escapedField NOT IN (${placeholders.join(", ")})');
                        }

                    case QueryOperator.EXISTS:
                        if (value == true) {
                            conditions.push('$escapedField IS NOT NULL');
                        } else {
                            conditions.push('$escapedField IS NULL');
                        }

                    case QueryOperator.REGEX:
                        params.push(value);
                        conditions.push('$escapedField REGEXP ?');

                    case QueryOperator.NOT:
                        var notCond = parseQueryCondition(field, value, params);
                        conditions.push('NOT ($notCond)');
                }
            }

            return conditions.length > 0 ? '(' + conditions.join(' AND ') + ')' : '1=1';
        } else {
            params.push(serializeValue(field, condition));
            return '$escapedField = ?';
        }
    }

    /**
     * Builds WHERE clause from query
     */
    private function buildWhereClause(query: Query, params: Array<Dynamic>): String {
        if (query == null) return '';

        var conditions = [];

        for (field in Reflect.fields(query)) {
            var value = Reflect.field(query, field);

            if (field == QueryOperator.OR) {
                if (Std.isOfType(value, Array)) {
                    var orConditions = [];
                    var arr: Array<Query> = cast value;
                    for (subQuery in arr) {
                        var subCond = buildWhereClause(subQuery, params);
                        if (subCond.length > 0) {
                            orConditions.push('(' + subCond + ')');
                        }
                    }
                    if (orConditions.length > 0) {
                        conditions.push('(' + orConditions.join(' OR ') + ')');
                    }
                }
            } else if (field == QueryOperator.AND) {
                if (Std.isOfType(value, Array)) {
                    var andConditions = [];
                    var arr: Array<Query> = cast value;
                    for (subQuery in arr) {
                        var subCond = buildWhereClause(subQuery, params);
                        if (subCond.length > 0) {
                            andConditions.push('(' + subCond + ')');
                        }
                    }
                    if (andConditions.length > 0) {
                        conditions.push('(' + andConditions.join(' AND ') + ')');
                    }
                }
            } else {
                conditions.push(parseQueryCondition(field, value, params));
            }
        }

        return conditions.join(' AND ');
    }

    /**
     * Inserts a new document
     *
     * @param doc The document to insert
     * @return The ID of the inserted document
     */
    public function insert(doc: T): Int {
        ensureColumns(doc);

        var fields = [];
        var values = [];
        var placeholders = [];

        for (field in getDocumentFields(doc)) {
            fields.push(escapeFieldName(field));
            values.push(serializeValue(field, getDocumentField(doc, field)));
            placeholders.push("?");
        }

        var sql: String;
        if (fields.length == 0) {
            // Handle empty document - insert with default values only
            sql = 'INSERT INTO $tableName DEFAULT VALUES';
            executeQuery(sql, []);
        } else {
            var fieldStr = fields.join(", ");
            var placeholderStr = placeholders.join(", ");
            sql = 'INSERT INTO $tableName ($fieldStr) VALUES ($placeholderStr)';
            executeQuery(sql, values);
        }
        return connection.lastInsertId();
    }

    /**
     * Finds documents matching the query
     *
     * @param query The query criteria
     * @param options Query options
     * @return Array of matching documents
     */
    public function find(?query: Query, ?options: {?limit: Int, ?offset: Int, ?orderBy: String}): Array<T> {
        var sql = 'SELECT * FROM $tableName';
        var params = [];

        var whereClause = buildWhereClause(query, params);
        if (whereClause.length > 0) {
            sql += ' WHERE ' + whereClause;
        }

        if (options != null) {
            if (options.orderBy != null) {
                sql += ' ORDER BY ' + options.orderBy;
            }
            if (options.limit != null) {
                sql += ' LIMIT ' + options.limit;
                if (options.offset != null) {
                    sql += ' OFFSET ' + options.offset;
                }
            }
        }

        var result = executeQuery(sql, params);
        var documents = [];

        // Process all rows immediately to avoid ResultSet finalization issues
        var rows = [];
        while (result.hasNext()) {
            rows.push(result.next());
        }

        for (row in rows) {
            var doc: Dynamic = {};
            for (field in Reflect.fields(row)) {
                var value = Reflect.field(row, field);
                setDocumentField(doc, field, deserializeValue(field, value));
            }
            documents.push(cast doc);
        }

        return documents;
    }

    /**
     * Finds a single document
     *
     * @param query The query criteria
     * @return The document or null
     */
    public function findOne(?query: Query): Null<T> {
        var results = find(query, {limit: 1});
        return results.length > 0 ? results[0] : null;
    }

    /**
     * Finds a document by ID
     *
     * @param id The document ID
     * @return The document or null
     */
    public function findById(id: Int): Null<T> {
        return findOne({_id: id});
    }

    /**
     * Updates documents matching the query
     *
     * @param query The query criteria
     * @param updates The updates to apply
     * @return Number of documents updated
     */
    public function update(query: Query, updates: Dynamic): Int {
        ensureColumns(updates);

        var setClauses = [];
        var values = [];

        for (field in getDocumentFields(updates)) {
            if (field != "_id") {
                setClauses.push('${escapeFieldName(field)} = ?');
                values.push(serializeValue(field, getDocumentField(updates, field)));
            }
        }

        var params = [];
        var whereClause = buildWhereClause(query, params);

        for (p in params) {
            values.push(p);
        }

        if (setClauses.length == 0) return 0;

        var sql = 'UPDATE $tableName SET ' + setClauses.join(', ');
        if (whereClause.length > 0) {
            sql += ' WHERE ' + whereClause;
        }

        executeQuery(sql, values);
        return getChanges();
    }

    /**
     * Updates a document by ID
     *
     * @param id The document ID
     * @param updates The updates to apply
     * @return True if updated
     */
    public function updateById(id: Int, updates: Dynamic): Bool {
        return update({_id: id}, updates) > 0;
    }

    /**
     * Deletes documents matching the query
     *
     * @param query The query criteria
     * @return Number of documents deleted
     */
    public function delete(query: Query): Int {
        var params = [];
        var whereClause = buildWhereClause(query, params);

        var sql = 'DELETE FROM $tableName';
        if (whereClause.length > 0) {
            sql += ' WHERE ' + whereClause;
        }

        executeQuery(sql, params);
        return getChanges();
    }

    /**
     * Deletes a document by ID
     *
     * @param id The document ID
     * @return True if deleted
     */
    public function deleteById(id: Int): Bool {
        return delete({_id: id}) > 0;
    }

    /**
     * Creates an index
     *
     * @param index Index definition
     */
    public function createIndex(index: IndexDef): Void {

        // Ensure all fields exist as columns before creating index - delegate to ensureColumns
        var tempDoc = {};
        for (field in index.fields) {
            if (!typeCache.exists(field)) {
                // Create a temporary document with this field to trigger ensureColumns
                Reflect.setField(tempDoc, field, ""); // TEXT type
            } else {
            }
        }

        // Use ensureColumns to properly add any missing columns and update metadata
        if (Reflect.fields(tempDoc).length > 0) {
            ensureColumns(tempDoc);
        }

        // Create the actual index
        var unique = index.unique ? "UNIQUE" : "";
        var escapedFields = index.fields.map(function(field) return escapeFieldName(field));
        var fields = escapedFields.join(", ");
        var sql = 'CREATE $unique INDEX IF NOT EXISTS ${index.name} ON $tableName ($fields)';
        executeDDL(sql);

        // Store index metadata
        var fieldNamesJson = haxe.Json.stringify(index.fields);
        var uniqueFlag = index.unique ? 1 : 0;
        var indexSql = 'INSERT OR REPLACE INTO ${tableName}_indexes (index_name, field_names, is_unique) VALUES (?, ?, ?)';
        executeDDL(indexSql, [index.name, fieldNamesJson, uniqueFlag]);

    }

    /**
     * Drops an index
     *
     * @param indexName Name of the index
     */
    public function dropIndex(indexName: String): Void {
        executeQuery('DROP INDEX IF EXISTS $indexName');

        // Remove index metadata
        var removeSql = 'DELETE FROM ${tableName}_indexes WHERE index_name = ?';
        executeQuery(removeSql, [indexName]);
    }

    /**
     * Counts documents matching the query
     *
     * @param query The query criteria
     * @return Count of matching documents
     */
    public function count(?query: Query): Int {
        var sql = 'SELECT COUNT(*) as count FROM $tableName';
        var params = [];

        var whereClause = buildWhereClause(query, params);
        if (whereClause.length > 0) {
            sql += ' WHERE ' + whereClause;
        }

        var result = executeQuery(sql, params);

        // Process rows immediately to avoid ResultSet finalization issues
        var rows = [];
        while (result.hasNext()) {
            rows.push(result.next());
        }

        return rows.length > 0 ? rows[0].count : 0;
    }

    /**
     * Gets field type information
     *
     * @return Map of field names to types
     */
    public function getFieldTypes(): Map<String, FieldType> {
        return typeCache.copy();
    }
}