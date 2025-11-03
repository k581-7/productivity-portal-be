# RSpec Model Testing Guide

## Setup

1. Install the required gems:
```bash
bundle install
```

2. Set up the test database:
```bash
rails db:test:prepare
```

## Running Tests

### Run all model tests
```bash
bundle exec rspec spec/models
```

### Run specific model test
```bash
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/models/supplier_spec.rb
bundle exec rspec spec/models/prod_entry_spec.rb
bundle exec rspec spec/models/daily_prod_spec.rb
bundle exec rspec spec/models/summary_dashboard_spec.rb
bundle exec rspec spec/models/csv_upload_spec.rb
bundle exec rspec spec/models/todo_spec.rb
```

### Run with documentation format (detailed output)
```bash
bundle exec rspec spec/models --format documentation
```

## What Gets Tested

Each model spec tests:

1. **Associations** - Tests that relationships between models work correctly
2. **Validations** - Tests that required fields are enforced
3. **Common Tests** - Tests basic CRUD operations and model-specific logic

## Test Output

✅ **Green dots (.)** = Tests passing  
❌ **Red F** = Tests failing

Example output:
```
.......

Finished in 0.5 seconds
7 examples, 0 failures
```

## Understanding the Tests

### Simple Structure
Each test follows this pattern:

```ruby
it 'describes what is being tested' do
  # 1. Create test data
  user = User.create!(email: 'test@example.com', name: 'Test', role: :developer)
  
  # 2. Perform action or check condition
  expect(user.developer?).to be true
end
```

### Association Tests
```ruby
it 'has many todos' do
  user = User.create!(...)
  todo = Todo.create!(user: user, content: 'Test')
  
  expect(user.todos).to include(todo)
end
```

### Validation Tests
```ruby
it 'requires content' do
  todo = Todo.new(user: user)  # Missing content
  
  expect(todo.save).to be false
end
```

## Troubleshooting

### If tests fail due to missing tables:
```bash
rails db:migrate RAILS_ENV=test
```

### Reset test database:
```bash
rails db:reset RAILS_ENV=test
```

### Check specific test line:
```bash
bundle exec rspec spec/models/user_spec.rb:10
```
