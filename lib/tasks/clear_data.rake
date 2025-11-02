namespace :data do
  desc "Clear all productivity data but keep users"
  task clear_all: :environment do
    puts "Starting data cleanup..."
    puts "=" * 50
    
    # Clear ProdEntries
    prod_entries_count = ProdEntry.count
    ProdEntry.destroy_all
    puts "✓ Deleted #{prod_entries_count} ProdEntry records"
    
    # Clear DailyProds
    daily_prods_count = DailyProd.count
    DailyProd.destroy_all
    puts "✓ Deleted #{daily_prods_count} DailyProd records"
    
    # Clear CsvUploads
    csv_uploads_count = CsvUpload.count
    CsvUpload.destroy_all
    puts "✓ Deleted #{csv_uploads_count} CsvUpload records"
    
    # Reset Supplier totals to zero
    suppliers_count = Supplier.count
    Supplier.update_all(
      manually_mapped: 0,
      incorrect_supplier_data: 0,
      insufficient_info: 0,
      created_property: 0,
      reactivated_total: 0,
      accepted_total: 0,
      dismissed_total: 0,
      duplicate_count: 0,
      bs_manually_mapped: 0,
      bs_incorrect_supplier_data: 0,
      bs_insufficient_info: 0,
      bs_created_property: 0,
      bs_reactivated_total: 0,
      nc_manually_mapped: 0,
      nc_incorrect_supplier: 0,
      nc_created_property: 0,
      nc_reactivated_total: 0,
      jp_props: 0,
      automapping_covered_total: 0,
      manual_total: 0
    )
    puts "✓ Reset #{suppliers_count} Supplier totals to zero"
    
    # Keep Users intact
    users_count = User.count
    puts "✓ Kept #{users_count} User records (unchanged)"
    
    puts "=" * 50
    puts "Data cleanup completed successfully!"
    puts "Summary:"
    puts "  - ProdEntries: #{prod_entries_count} deleted"
    puts "  - DailyProds: #{daily_prods_count} deleted"
    puts "  - CsvUploads: #{csv_uploads_count} deleted"
    puts "  - Suppliers: #{suppliers_count} reset to zero"
    puts "  - Users: #{users_count} kept intact"
  end
end
