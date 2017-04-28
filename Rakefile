# frozen_string_literal: true

require 'rubocop/rake_task'
require 'rake/testtask'

RuboCop::RakeTask.new

require 'scraper_test'
ScraperTest::RakeTask.new.install_tasks

task test: 'test:data'
task default: %w[rubocop test]
