---
name: sql-query-optimization
description: Reviews and optimizes SQL queries for MySQL, Oracle, and Snowflake databases, checking for performance issues, indexing opportunities, and anti-patterns
---

# SQL Query Optimization Skill

This skill helps review and optimize SQL queries for performance, maintainability, and best practices across MySQL, Oracle, and Snowflake platforms.

## When to Use This Skill

Use this skill when:
- Writing new SQL queries
- Reviewing existing queries for performance issues
- Investigating slow query performance
- Conducting code reviews that include SQL
- Optimizing stored procedures
- Planning database migrations

## Optimization Process

### 1. Initial Query Analysis

First, examine the query structure:
- Identify the tables being accessed
- Check JOIN types and conditions
- Review WHERE clause filtering
- Analyze aggregate functions and GROUP BY
- Check for subqueries and CTEs

### 2. Performance Anti-Patterns Check

Review for these common issues:

**SELECT * Usage**
- Flag any SELECT * in production code
- Recommend specifying only needed columns
- Note impact on network traffic and memory

**N+1 Query Problems**
- Identify queries that could be in loops
- Suggest JOIN operations instead of multiple queries
- Look for opportunities to batch operations

**Missing WHERE Clauses**
- Flag queries without filtering on large tables
- Suggest appropriate filtering conditions
- Check for accidental full table scans

**Implicit Type Conversions**
- Check for type mismatches in WHERE and JOIN conditions
- Flag columns wrapped in functions (prevents index usage)
- Suggest explicit type conversions where appropriate

**Subquery Inefficiencies**
- Identify correlated subqueries that run repeatedly
- Suggest JOIN alternatives where applicable
- Consider CTE refactoring for readability

**DISTINCT Overuse**
- Question necessity of DISTINCT
- Often indicates JOIN problems
- Suggest fixing underlying data model issues

### 3. Indexing Recommendations

Analyze potential indexing opportunities:

**WHERE Clause Columns**
- Identify frequently filtered columns
- Consider composite indexes for multiple conditions
- Note index selectivity importance

**JOIN Columns**
- Ensure foreign keys are indexed
- Check for missing indexes on JOIN conditions
- Consider covering indexes for frequent queries

**ORDER BY and GROUP BY**
- Identify sort operations that could use indexes
- Suggest composite indexes matching sort order
- Note when filesorts are unavoidable

### 4. Platform-Specific Optimizations

**MySQL Specific:**
- Check for proper use of LIMIT
- Review InnoDB vs MyISAM considerations
- Suggest EXPLAIN analysis for complex queries
- Check for proper use of indexes (FORCE INDEX if needed)

**Oracle Specific:**
- Review hint usage appropriately
- Check bind variable usage
- Analyze execution plans with EXPLAIN PLAN
- Consider partitioning for large tables

**Snowflake Specific:**
- Review cluster key opportunities
- Check for appropriate use of RESULT_SCAN
- Suggest query pruning opportunities
- Consider materialized views for complex aggregations
- Note warehouse size implications

### 5. Query Refactoring Suggestions

**Complex Query Breakdown:**
- Suggest CTEs for readability
- Break down complex nested queries
- Use temporary tables for multi-step operations

**Set-Based Operations:**
- Prefer set-based operations over cursors
- Suggest bulk operations instead of row-by-row
- Use appropriate aggregate functions

**JOIN Optimization:**
- Review JOIN order
- Suggest appropriate JOIN types (INNER vs LEFT vs EXISTS)
- Check for unnecessary JOINs

### 6. Code Quality and Maintainability

**Readability:**
- Use consistent formatting
- Add comments for complex logic
- Use meaningful table aliases
- Break long queries into readable sections with CTEs

**Parameterization:**
- Use parameterized queries (prevent SQL injection)
- Avoid dynamic SQL where possible
- Use stored procedures for complex reusable logic

**Error Handling:**
- Consider NULL handling explicitly
- Use COALESCE or ISNULL appropriately
- Handle division by zero scenarios

## Review Output Format

Provide feedback in this structure:

1. **Summary**: Overall assessment and main issues
2. **Critical Issues**: Performance problems that need immediate attention
3. **Optimization Opportunities**: Suggested improvements with expected impact
4. **Indexing Recommendations**: Specific index suggestions with DDL
5. **Refactored Query**: Optimized version of the query (if applicable)
6. **Explanation**: Why the changes improve performance

## Example Review

**Original Query:**
```sql
SELECT * FROM orders o
WHERE YEAR(order_date) = 2024
  AND customer_id IN (SELECT customer_id FROM customers WHERE status = 'active')
```

**Review:**
1. **Summary**: Query has performance issues with function on indexed column and subquery
2. **Critical Issues**: 
   - YEAR() function prevents index usage on order_date
   - SELECT * retrieves unnecessary columns
3. **Optimization Opportunities**:
   - Use date range instead of YEAR() function
   - Convert subquery to JOIN
   - Specify only needed columns
4. **Refactored Query**:
```sql
SELECT o.order_id, o.order_date, o.total_amount, o.customer_id
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date >= '2024-01-01' 
  AND o.order_date < '2025-01-01'
  AND c.status = 'active'
```

## Validation Steps

Before finalizing recommendations:
1. Ensure refactored query returns same results
2. Verify suggested indexes don't duplicate existing ones
3. Consider query frequency and data volume in recommendations
4. Note any assumptions made about table sizes or distributions
5. Suggest EXPLAIN plan analysis for validation

## Best Practices Reminder

- Always test optimizations in non-production first
- Measure performance before and after changes
- Consider maintenance overhead of additional indexes
- Document reasoning for complex optimizations
- Review execution plans, not just query text
