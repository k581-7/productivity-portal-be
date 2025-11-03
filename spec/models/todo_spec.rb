require 'rails_helper'

RSpec.describe Todo, type: :model do
  describe 'associations' do
    it 'belongs to user' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      todo = Todo.create!(user: user, content: 'Test task')
      
      expect(todo.user).to eq(user)
    end
  end

  describe 'validations and common tests' do
    it 'can be created with valid attributes' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      todo = Todo.new(user: user, content: 'Test task')
      
      expect(todo.save).to be true
    end

    it 'requires content' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      todo = Todo.new(user: user)
      
      expect(todo.save).to be false
    end

    it 'can mark todo as completed' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      todo = Todo.create!(user: user, content: 'Test task', completed: false)
      
      todo.update(completed: true)
      
      expect(todo.completed).to be true
    end

    it 'has scopes for completed and incomplete' do
      user = User.create!(email: 'test@example.com', name: 'Test User', role: :developer)
      completed_todo = Todo.create!(user: user, content: 'Done', completed: true)
      incomplete_todo = Todo.create!(user: user, content: 'Not done', completed: false)
      
      expect(Todo.completed).to include(completed_todo)
      expect(Todo.incomplete).to include(incomplete_todo)
    end
  end
end
