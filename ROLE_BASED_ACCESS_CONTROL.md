# Role-Based Access Control (RBAC) Documentation

This document outlines the role-based access control implemented in the Productivity Portal Backend API.

## User Roles

The system has 4 user roles with different permission levels:

1. **Developer** - Full system access
2. **Leader** - Management and editing capabilities
3. **Junior** - Basic employee access
4. **Guest** - View-only limited access

## Access Control Matrix

### Dashboard
- ✅ **Junior**: View access
- ✅ **Leader**: View access
- ✅ **Guest**: View access
- ✅ **Developer**: Full access

### Productivity Entry (Prod Entries)
- ✅ **Junior**: View own entries only
- ✅ **Leader**: Full access (create, view all, upload CSV, view upload history, delete uploads)
- ❌ **Guest**: NO ACCESS
- ✅ **Developer**: Full access

### Daily Prod
- ✅ **Junior**: View-only (cannot edit)
- ✅ **Leader**: Full access (view and edit mode with pencil icon)
- ✅ **Guest**: View-only (cannot edit)
- ✅ **Developer**: Full access

### Suppliers
- ❌ **Junior**: NO ACCESS
- ✅ **Leader**: Full access (view, create, edit, delete)
- ✅ **Guest**: View-only (cannot create/edit/delete)
- ✅ **Developer**: Full access

### Summary
- ✅ **Junior**: View access (sees all users' team performance)
- ✅ **Leader**: View access (sees all users' team performance)
- ✅ **Guest**: View access (sees all users' team performance)
- ✅ **Developer**: Full access (sees all users' team performance)

### Upload History
- ❌ **Junior**: NO ACCESS
- ✅ **Leader**: Full access (view and delete uploads)
- ❌ **Guest**: NO ACCESS
- ✅ **Developer**: Full access

### User Management
- ❌ **Junior**: NO ACCESS
- ❌ **Leader**: NO ACCESS
- ❌ **Guest**: NO ACCESS
- ✅ **Developer**: Full access (approve users, disable/activate, change roles)

## API Endpoint Security

### Application Controller (`app/controllers/application_controller.rb`)

Base authorization methods available to all controllers:

- `authenticate_user!` - Ensures user is logged in
- `authorize_developer!` - Developer only
- `authorize_leader!` - Leader only
- `authorize_developer_or_leader!` - Developer or Leader
- `authorize_not_junior!` - Everyone except Junior (Guest, Leader, Developer)
- `authorize_junior_or_higher!` - Junior, Leader, or Developer (excludes Guest)
- `authorize_can_edit!` - Can edit resources (Developer or Leader only)
- `check_user_status!` - Ensures user is approved and not disabled

### Users Controller (`app/controllers/api/v1/users_controller.rb`)

**Before Actions:**
- `before_action :authenticate_user!` - All actions
- `before_action :authorize_developer!` - index, pending, approve, disable, activate, update_role

**Endpoints:**
- `GET /api/v1/users` - Developer only
- `GET /api/v1/users/pending` - Developer only
- `GET /api/v1/users/current` - All authenticated users
- `PATCH /api/v1/users/:id/approve` - Developer only
- `PATCH /api/v1/users/:id/disable` - Developer only
- `PATCH /api/v1/users/:id/activate` - Developer only
- `PATCH /api/v1/users/:id` - Developer only

### Suppliers Controller (`app/controllers/api/v1/suppliers_controller.rb`)

**Before Actions:**
- `before_action :authenticate_user!` - All actions
- `before_action :check_junior_access!` - All actions (blocks Junior role)
- `before_action :authorize_can_edit!` - create, update, destroy

**Endpoints:**
- `GET /api/v1/suppliers` - Guest, Leader, Developer (view only)
- `GET /api/v1/suppliers/:id` - Guest, Leader, Developer (view only)
- `GET /api/v1/suppliers/summary` - Guest, Leader, Developer (view only)
- `POST /api/v1/suppliers` - Leader, Developer only
- `PATCH /api/v1/suppliers/:id` - Leader, Developer only
- `DELETE /api/v1/suppliers/:id` - Leader, Developer only

### Daily Prods Controller (`app/controllers/api/v1/daily_prods_controller.rb`)

**Before Actions:**
- `before_action :authenticate_user!` - All actions
- `before_action :authorize_can_edit!` - update_cell, delete_status, delete_entry

**Endpoints:**
- `GET /api/v1/daily_prods` - All authenticated users (view only)
- `GET /api/v1/daily_prods/summary` - All authenticated users (view only)
- `PATCH /api/v1/daily_prods/update_cell` - Leader, Developer only
- `DELETE /api/v1/daily_prods/delete_status` - Leader, Developer only
- `DELETE /api/v1/daily_prods/delete_entry` - Leader, Developer only

### Prod Entries Controller (`app/controllers/api/v1/prod_entries_controller.rb`)

**Before Actions:**
- `before_action :authenticate_user!` - All actions
- `before_action :check_guest_access!` - All actions (blocks Guest role)
- `before_action :authorize_developer_or_leader!` - create, upload_history, delete_upload

**Endpoints:**
- `GET /api/v1/prod_entries` - Junior, Leader, Developer (Junior sees own entries only)
- `POST /api/v1/prod_entries` - Leader, Developer only
- `GET /api/v1/prod_entries/upload_history` - Leader, Developer only
- `DELETE /api/v1/prod_entries/delete_upload/:batch_id` - Leader, Developer only

### Summary Controller (`app/controllers/api/v1/summary_controller.rb`)

**Before Actions:**
- `before_action :authenticate_user!` - All actions

**Endpoints:**
- `GET /api/v1/summary/dashboard` - All authenticated users can view all users' team performance data

## Security Implementation

### Backend Protection

All endpoints are protected at the controller level using `before_action` filters. This ensures that even if a user receives a direct link to a restricted endpoint, they will receive a `403 Forbidden` error if they don't have the required permissions.

### Error Responses

When a user attempts to access a restricted resource:

**Unauthorized (401):**
```json
{
  "error": "Unauthorized"
}
```

**Forbidden (403):**
```json
{
  "error": "Access denied. [Role] role does not have access to [Resource]."
}
```

Examples:
- `"Access denied. Junior role does not have access to Suppliers."`
- `"Access denied. Guest role does not have access to Productivity Entry."`
- `"Access denied. Developer role required."`
- `"You do not have permission to edit this resource."`

## Testing Access Control

To test that the access control is working:

1. **Create test users with different roles** in your database
2. **Generate JWT tokens** for each role
3. **Make API requests** to restricted endpoints with different role tokens
4. **Verify** that:
   - Junior cannot access `/api/v1/suppliers`
   - Guest cannot access `/api/v1/prod_entries`
   - Junior can now access `/api/v1/summary/dashboard` for team performance
   - Only Developer can access `/api/v1/users`
   - Only Leader/Developer can edit Daily Prod cells
   - Only Leader/Developer can create/edit Suppliers

## Role Assignment

User roles are assigned by Developers through the User Management interface:

1. New users sign up and are marked as `approved: false`
2. Developer approves the user and assigns a role
3. User can then access endpoints based on their assigned role
4. Developer can change user roles or disable users at any time

## Additional Security Notes

- All endpoints require authentication via JWT token in the `Authorization` header
- Users must be approved (`approved: true`) and not disabled (`disabled: false`) to access the system
- Role checks are performed on every request, not cached
- Direct API access via links will be blocked if user doesn't have proper permissions
