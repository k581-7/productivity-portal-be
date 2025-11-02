# Frontend Implementation Guide: Upload Undo Feature

## Overview
The backend now tracks each CSV upload with a unique `batch_id` and provides endpoints to view upload history and delete specific uploads.

---

## Backend Endpoints Available

### 1. **GET `/api/v1/prod_entries/upload_history`**
Returns list of all CSV uploads.

**Response:**
```json
[
  {
    "id": 1,
    "batch_id": "abc-123-uuid",
    "filename": "autosheet.csv",
    "source_type": "autosheet",
    "manualsheet_type": null,
    "supplier": {
      "id": 5,
      "name": "Supplier Name"
    },
    "uploaded_by": {
      "id": 2,
      "name": "Admin User"
    },
    "upload_date": "2025-11-03T10:30:00Z",
    "entry_count": 25
  }
]
```

### 2. **DELETE `/api/v1/prod_entries/delete_upload/:batch_id`**
Deletes all data from a specific upload and recalculates totals.

**Response:**
```json
{
  "message": "Upload deleted successfully",
  "deleted_entries": 25,
  "affected_dates": [
    {"user_id": 17, "date": "2025-10-03"},
    {"user_id": 18, "date": "2025-10-03"}
  ]
}
```

### 3. **Updated Upload Response**
When uploading CSV files, the response now includes `batch_id`:

**POST `/api/v1/prod_entries`**
```json
{
  "message": "Files processed and data stored successfully.",
  "batch_id": "abc-123-uuid",
  "upload_id": 1
}
```

---

## Frontend Implementation Options

### **Option 1: Upload History Page (Recommended)**

Create a new page/route: `/upload-history` or `/csv-uploads`

**Features:**
- Table showing all CSV uploads
- Columns: Date, Filename, Type, Supplier, Uploaded By, # of Entries, Delete Button
- Confirm before delete
- Refresh data after deletion

**Sample React Component:**
```jsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';

function UploadHistory() {
  const [uploads, setUploads] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchUploads();
  }, []);

  const fetchUploads = async () => {
    try {
      const response = await axios.get('/api/v1/prod_entries/upload_history');
      setUploads(response.data);
    } catch (error) {
      console.error('Error fetching uploads:', error);
    }
  };

  const handleDelete = async (batchId, filename) => {
    if (!window.confirm(`Are you sure you want to delete upload: ${filename}?\n\nThis will remove all associated data and recalculate totals.`)) {
      return;
    }

    setLoading(true);
    try {
      await axios.delete(`/api/v1/prod_entries/delete_upload/${batchId}`);
      alert('Upload deleted successfully!');
      fetchUploads(); // Refresh list
      // Optionally: trigger refresh of Daily Prod and Supplier pages
    } catch (error) {
      console.error('Error deleting upload:', error);
      alert('Failed to delete upload');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="upload-history">
      <h1>CSV Upload History</h1>
      <table>
        <thead>
          <tr>
            <th>Upload Date</th>
            <th>Filename</th>
            <th>Type</th>
            <th>Supplier</th>
            <th>Uploaded By</th>
            <th>Entries</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {uploads.map(upload => (
            <tr key={upload.batch_id}>
              <td>{new Date(upload.upload_date).toLocaleString()}</td>
              <td>{upload.filename}</td>
              <td>
                {upload.source_type}
                {upload.manualsheet_type && ` (${upload.manualsheet_type})`}
              </td>
              <td>{upload.supplier?.name || 'N/A'}</td>
              <td>{upload.uploaded_by?.name || 'Unknown'}</td>
              <td>{upload.entry_count}</td>
              <td>
                <button 
                  onClick={() => handleDelete(upload.batch_id, upload.filename)}
                  disabled={loading}
                  className="btn-delete"
                >
                  🗑️ Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default UploadHistory;
```

---

### **Option 2: Quick Undo Button (Simpler)**

Add to the Prod Entry upload page:

```jsx
function ProdEntryUpload() {
  const [lastUpload, setLastUpload] = useState(null);

  const handleUpload = async (formData) => {
    try {
      const response = await axios.post('/api/v1/prod_entries', formData);
      // Store the batch_id from response
      setLastUpload({
        batch_id: response.data.batch_id,
        upload_id: response.data.upload_id,
        timestamp: new Date()
      });
      alert('Upload successful!');
    } catch (error) {
      console.error('Upload failed:', error);
    }
  };

  const handleUndo = async () => {
    if (!lastUpload) return;

    if (!window.confirm('Undo the last upload? This will remove all data from that upload.')) {
      return;
    }

    try {
      await axios.delete(`/api/v1/prod_entries/delete_upload/${lastUpload.batch_id}`);
      alert('Upload undone successfully!');
      setLastUpload(null);
      // Refresh relevant pages
    } catch (error) {
      console.error('Undo failed:', error);
      alert('Failed to undo upload');
    }
  };

  return (
    <div>
      {/* Upload form here */}
      
      {lastUpload && (
        <div className="undo-section">
          <button onClick={handleUndo} className="btn-undo">
            ↶ Undo Last Upload
          </button>
          <span>Uploaded {lastUpload.timestamp.toLocaleTimeString()}</span>
        </div>
      )}
    </div>
  );
}
```

---

## Navigation Update

Add a menu item to access the Upload History page:

```jsx
// In your navigation/sidebar
<nav>
  <Link to="/daily-prod">Daily Productivity</Link>
  <Link to="/suppliers">Suppliers</Link>
  <Link to="/prod-entry">Upload CSV</Link>
  <Link to="/upload-history">📜 Upload History</Link> {/* NEW */}
  <Link to="/users">User Management</Link>
</nav>
```

---

## Important Notes for Frontend

1. **Authorization**: Only leaders and developers can access these endpoints
2. **Refresh Data**: After deleting an upload, refresh:
   - Daily Prod page (data recalculated)
   - Supplier Details page (totals recalculated)
   - Upload History page
3. **Confirmation**: Always confirm before deleting (destructive action)
4. **Loading States**: Show loading indicator during delete operation
5. **Error Handling**: Handle 404 (upload not found), 403 (unauthorized), etc.

---

## Testing Steps

1. Upload a CSV file → Note the `batch_id` in response
2. Go to Upload History page → See the upload listed
3. Click Delete → Confirm deletion
4. Check Daily Prod and Supplier pages → Data should be removed and totals recalculated
5. Upload multiple files for same date → Each gets unique batch_id
6. Delete one → Only that upload's data is removed

---

## UI/UX Recommendations

- **Icon**: Use 🗑️ or trash icon for delete button
- **Color**: Red for delete button
- **Confirmation**: Use modal or confirm dialog
- **Success**: Show toast/notification after successful delete
- **Disable**: Disable delete button while operation in progress
- **Sort**: Show most recent uploads first (already sorted by backend)
