# Frontend Access Control Quick Reference

## Role-Based UI Visibility Guide

This guide helps frontend developers implement proper UI visibility based on user roles.

## Getting Current User Role

```javascript
// Assume you fetch current user from: GET /api/v1/users/current
const currentUser = {
  id: 1,
  name: "John Doe",
  email: "john@example.com",
  role: "junior" // or "leader", "guest", "developer"
};
```

## Role Checks

```javascript
const isDeveloper = currentUser.role === 'developer';
const isLeader = currentUser.role === 'leader';
const isJunior = currentUser.role === 'junior';
const isGuest = currentUser.role === 'guest';

// Composite checks
const canEdit = isDeveloper || isLeader;
const canAccessSuppliers = isDeveloper || isLeader || isGuest; // NOT Junior
const canAccessSummary = isDeveloper || isLeader || isGuest; // NOT Junior
const canAccessProdEntries = isDeveloper || isLeader || isJunior; // NOT Guest
```

## Navigation Menu Visibility

```javascript
// Example navigation structure
const navigation = [
  {
    name: 'Dashboard',
    path: '/dashboard',
    visible: true // All roles
  },
  {
    name: 'Productivity Entry',
    path: '/prod-entries',
    visible: !isGuest // Junior, Leader, Developer
  },
  {
    name: 'Daily Prod',
    path: '/daily-prod',
    visible: true // All roles (but edit mode depends on role)
  },
  {
    name: 'Suppliers',
    path: '/suppliers',
    visible: !isJunior // Guest, Leader, Developer
  },
  {
    name: 'Summary',
    path: '/summary',
    visible: !isJunior // Guest, Leader, Developer
  },
  {
    name: 'Upload History',
    path: '/upload-history',
    visible: canEdit // Leader, Developer
  },
  {
    name: 'User Management',
    path: '/users',
    visible: isDeveloper // Developer only
  }
];
```

## Feature-Level Permissions

### Dashboard
```javascript
// All roles can view
showDashboard: true
```

### Productivity Entry
```javascript
// Junior, Leader, Developer can view
showProdEntries: !isGuest

// Only Leader and Developer can upload CSV
showUploadButton: canEdit

// Only Leader and Developer can view upload history
showUploadHistory: canEdit
```

### Daily Prod
```javascript
// All roles can view
showDailyProd: true

// Only Leader and Developer can edit (pencil icon)
enableEditMode: canEdit

// Hide edit buttons for Junior and Guest
showEditButtons: canEdit
showDeleteButtons: canEdit
```

### Suppliers
```javascript
// Guest, Leader, Developer can view (NOT Junior)
showSuppliers: !isJunior

// Only Leader and Developer can create/edit/delete
showCreateButton: canEdit
showEditButton: canEdit
showDeleteButton: canEdit
enableEditForm: canEdit
```

### Summary
```javascript
// Guest, Leader, Developer can view (NOT Junior)
showSummary: !isJunior
```

### User Management
```javascript
// Only Developer can access
showUserManagement: isDeveloper
showApproveButton: isDeveloper
showDisableButton: isDeveloper
showRoleSelector: isDeveloper
```

## Route Guards (React Router Example)

```javascript
import { Navigate } from 'react-router-dom';

// Protected Route Component
const ProtectedRoute = ({ children, allowedRoles }) => {
  const currentUser = useCurrentUser(); // Your hook to get current user
  
  if (!currentUser) {
    return <Navigate to="/login" />;
  }
  
  if (allowedRoles && !allowedRoles.includes(currentUser.role)) {
    return <Navigate to="/unauthorized" />;
  }
  
  return children;
};

// Route Configuration
<Routes>
  <Route path="/dashboard" element={<Dashboard />} />
  
  <Route 
    path="/prod-entries" 
    element={
      <ProtectedRoute allowedRoles={['junior', 'leader', 'developer']}>
        <ProdEntries />
      </ProtectedRoute>
    } 
  />
  
  <Route path="/daily-prod" element={<DailyProd />} />
  
  <Route 
    path="/suppliers" 
    element={
      <ProtectedRoute allowedRoles={['guest', 'leader', 'developer']}>
        <Suppliers />
      </ProtectedRoute>
    } 
  />
  
  <Route 
    path="/summary" 
    element={
      <ProtectedRoute allowedRoles={['guest', 'leader', 'developer']}>
        <Summary />
      </ProtectedRoute>
    } 
  />
  
  <Route 
    path="/upload-history" 
    element={
      <ProtectedRoute allowedRoles={['leader', 'developer']}>
        <UploadHistory />
      </ProtectedRoute>
    } 
  />
  
  <Route 
    path="/users" 
    element={
      <ProtectedRoute allowedRoles={['developer']}>
        <UserManagement />
      </ProtectedRoute>
    } 
  />
</Routes>
```

## API Error Handling

```javascript
// When user tries to access restricted endpoint
const handleAPIError = (error) => {
  if (error.response?.status === 403) {
    // Forbidden - user doesn't have permission
    toast.error(error.response.data.error || 'Access denied');
    navigate('/dashboard'); // Redirect to safe page
  } else if (error.response?.status === 401) {
    // Unauthorized - user not logged in
    toast.error('Please log in');
    navigate('/login');
  }
};

// Example usage with axios
try {
  const response = await axios.get('/api/v1/suppliers');
  setSuppliers(response.data);
} catch (error) {
  handleAPIError(error);
}
```

## Conditional Rendering Examples

### Suppliers Page
```javascript
function SuppliersPage() {
  const { currentUser } = useAuth();
  const canEdit = ['developer', 'leader'].includes(currentUser.role);
  
  return (
    <div>
      <h1>Suppliers</h1>
      {canEdit && (
        <button onClick={handleCreate}>Create New Supplier</button>
      )}
      <table>
        {/* Table content */}
      </table>
    </div>
  );
}
```

### Daily Prod Page
```javascript
function DailyProdPage() {
  const { currentUser } = useAuth();
  const canEdit = ['developer', 'leader'].includes(currentUser.role);
  
  return (
    <div>
      <h1>Daily Productivity</h1>
      <table>
        <tbody>
          {data.map(row => (
            <tr key={row.id}>
              <td>{row.value}</td>
              <td>
                {canEdit && (
                  <>
                    <button onClick={() => handleEdit(row)}>✏️</button>
                    <button onClick={() => handleDelete(row)}>🗑️</button>
                  </>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

## Important Notes

1. **Always check permissions on the backend** - Frontend checks are for UX only
2. **Even with direct links**, the backend will reject unauthorized requests
3. **Hide UI elements** that users don't have permission to use
4. **Provide clear error messages** when access is denied
5. **Redirect users** to appropriate pages when they try to access restricted areas

## Testing Checklist

For each role, verify:

### Junior Role
- ✅ Can access Dashboard
- ✅ Can access Productivity Entry (view own entries)
- ✅ Can view Daily Prod (read-only, no edit buttons)
- ❌ Cannot access Suppliers
- ❌ Cannot access Summary
- ❌ Cannot access Upload History
- ❌ Cannot access User Management

### Leader Role
- ✅ Can access Dashboard
- ✅ Can access Productivity Entry (full access)
- ✅ Can edit Daily Prod (edit buttons visible)
- ✅ Can edit Suppliers
- ✅ Can access Summary
- ✅ Can access Upload History
- ❌ Cannot access User Management

### Guest Role
- ✅ Can access Dashboard
- ❌ Cannot access Productivity Entry
- ✅ Can view Daily Prod (read-only)
- ✅ Can view Suppliers (read-only, no edit buttons)
- ✅ Can access Summary
- ❌ Cannot access Upload History
- ❌ Cannot access User Management

### Developer Role
- ✅ Full access to everything
