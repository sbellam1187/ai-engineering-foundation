# Refactoring Techniques Reference

Before/after examples for common refactoring patterns used by the Code Simplifier Agent.

## Extract Method

**Before:**
```
function processOrder(order) {
  // 50 lines of validation
  // 30 lines of calculation
  // 20 lines of persistence
}
```

**After:**
```
function processOrder(order) {
  validateOrder(order);
  const total = calculateTotal(order);
  saveOrder(order, total);
}
```

## Guard Clauses

**Before:**
```
function process(data) {
  if (data != null) {
    if (data.isValid()) {
      if (data.hasItems()) {
        // actual logic
      }
    }
  }
}
```

**After:**
```
function process(data) {
  if (data == null) return;
  if (!data.isValid()) return;
  if (!data.hasItems()) return;
  
  // actual logic (no nesting)
}
```

## Extract Boolean Method

**Before:**
```
if (user.age >= 18 && user.hasLicense && !user.isSuspended && user.passedTest)
```

**After:**
```
if (user.canDrive())

// In User class:
boolean canDrive() {
  return age >= 18 && hasLicense && !isSuspended && passedTest;
}
```

## Remove Duplication

**Before:**
```
// In OrderService
total = items.stream().mapToDouble(i -> i.price * i.qty).sum();

// In CartService (same logic)
total = items.stream().mapToDouble(i -> i.price * i.qty).sum();
```

**After:**
```
// In PricingUtils
static double calculateTotal(List<Item> items) {
  return items.stream().mapToDouble(i -> i.price * i.qty).sum();
}
```

## Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Method length | > 15-20 lines | Extract to well-named helper method |
| Complex conditionals | > 2-3 conditions | Replace with guard clauses or extract boolean method |
| Deep nesting | > 3 levels | Invert conditions, extract methods, use functional approaches |
| Code duplication | Same code in 2+ places | Extract to shared method/utility |
| Poor naming | Single letters, abbreviations | Rename to describe purpose |
| Dead code | Unreachable, unused, commented | Delete entirely |
