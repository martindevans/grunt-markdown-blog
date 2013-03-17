###
Task: markdown
Description: generates HTML files from markdown files for static deployment
Dependencies: grunt, marked
Contributor: @searls
###

marked = require('marked')
_ = require('underscore')
fs = require('fs')
highlight = require('highlight.js')
grunt = require('grunt')
moment = require('moment')

marked.setOptions
  highlight: (code, lang) ->
    highlighted = if highlight.LANGUAGES[lang]?
      highlight.highlight(lang, code, true)
    else
      highlight.highlightAuto(code)
    highlighted.value


module.exports = (grunt) ->
  grunt.registerMultiTask "markdown", "generates HTML from markdown", ->
    config = _(
      title: "my blog"
      layouts:
        wrapper: "app/templates/wrapper.us"
        index: "app/templates/index.us"
        post: "app/templates/post.us"
        archive: "app/templates/archive.us"
      paths:
        markdown: "app/posts/*.md"
        posts: "posts"
        index: "index.html"
        archive: "archive.html"
      dest: "dist"
      context:
        js: "app.js"
        css: "app.css"
    ).extend(@options(@data))
    new MarkdownTask(config).run()

class MarkdownTask
  constructor: (@config) ->
    @writesHtml = new WritesHtml(@config.dest)
    @site = new Site(@config, @buildPosts(), new Layout(@config.layouts.post))
    @wrapper = new Layout(@config.layouts.wrapper, @config.context)

  run: ->
    @createPosts()
    @createIndex()
    @createArchive()

  createPosts: ->
    generatesHtml = new GeneratesHtml(@wrapper, new Layout(@config.layouts.post), @site)
    _(@site.posts).each (post) =>
      html = generatesHtml.generate(post)
      @writesHtml.write(html, post.htmlPath())

  createIndex: ->
    html = new GeneratesHtml(@wrapper, new Layout(@config.layouts.index), @site).generate()
    @writesHtml.write(html, @config.paths.index)

  createArchive: ->
    html = new GeneratesHtml(@wrapper, new Layout(@config.layouts.archive), @site).generate()
    @writesHtml.write(html, @config.paths.archive)

  buildPosts: ->
    _(@allMarkdownPosts()).map (markdownPath) =>
      new Post(markdownPath, @config.paths.posts)

  #private
  allMarkdownPosts: -> grunt.file.expand(@config.paths.markdown)

class GeneratesHtml
  constructor: (@wrapper, @template, @site) ->

  generate: (post) ->
    context = site: @site, post: post
    context.yield = @template.htmlFor(context)
    @wrapper.htmlFor(context)

class WritesHtml
  constructor: (@dest) ->

  write: (html, filePath) ->
    path = "#{@dest}/#{filePath}"
    grunt.log.writeln("Writing #{html.length} characters of html to #{path}")
    grunt.file.write(path, html)

class Layout
  constructor: (layoutPath, context = {}) ->
    @layout = _(grunt.file.read(layoutPath)).template()
    @context = context

  htmlFor: (specificContext) ->
    @layout(_(@context).extend(specificContext))

#--- models the site

class Site
  constructor: (config, posts, @postLayout) ->
    _(@).extend(config)
    @posts = _(posts).sortBy (p) -> p.fileName()

  olderPost: (post) ->
    return if _(@posts).first() == post
    @posts[_(@posts).indexOf(post) - 1]

  newerPost: (post) ->
    return if _(@posts).last() == post
    @posts[_(@posts).indexOf(post) + 1]

  htmlFor: (post) ->
    @postLayout.htmlFor(post: post, site: this)


class Post
  constructor: (@path, @htmlDirPath) ->

  content: ->
    markdown = grunt.file.read(@path)
    content = marked.parser(marked.lexer(markdown))

  title: ->
    dasherized = @path.match(/\/\d{4}-\d{2}-\d{2}-([^/]*).md/)?[1]
    title = dasherized?.replace(/-/g, " ")
    title || @fileName()

  htmlPath: ->
    "#{@htmlDirPath}/#{@fileName()}"

  fileName: ->
    name = @path.match(/\/([^/]*).md/)?[1]
    "#{name}.html"

  date: ->
    if date = @path.match(/\/(\d{4}-\d{2}-\d{2})/)?[1]
      moment(date).format('MMMM Do YYYY').toLowerCase()
