# Workaround to fix an issue with the annotate gem and route annotation
# https://github.com/ctran/annotate_models/issues/845
task routes: :environment do
  puts `bundle exec rails routes`
end