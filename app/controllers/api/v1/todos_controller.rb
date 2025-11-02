module Api
  module V1
    class TodosController < ApplicationController
      before_action :authenticate_user!
      before_action :set_todo, only: [:update, :destroy]
      
      # GET /api/v1/todos
      # Returns all todos for the authenticated user
      def index
        todos = current_user.todos.ordered
        
        render json: todos.map { |todo| format_todo(todo) }
      end
      
      # POST /api/v1/todos
      # Creates a new todo for the authenticated user
      def create
        todo = current_user.todos.build(todo_params)
        
        if todo.save
          render json: format_todo(todo), status: :created
        else
          render json: { errors: todo.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT/PATCH /api/v1/todos/:id
      # Updates a todo (typically to mark as complete/incomplete)
      def update
        if @todo.update(todo_params)
          render json: format_todo(@todo)
        else
          render json: { errors: @todo.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/todos/:id
      # Deletes a todo
      def destroy
        @todo.destroy
        head :no_content
      end
      
      private
      
      def set_todo
        @todo = current_user.todos.find_by(id: params[:id])
        
        unless @todo
          render json: { error: 'Todo not found' }, status: :not_found
        end
      end
      
      def todo_params
        params.require(:todo).permit(:content, :completed)
      end
      
      def format_todo(todo)
        {
          id: todo.id,
          content: todo.content,
          completed: todo.completed,
          created_at: todo.created_at,
          updated_at: todo.updated_at
        }
      end
    end
  end
end
