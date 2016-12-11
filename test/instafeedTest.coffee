# Set up Chai (http://chaijs.com)
chai = require 'chai'
chai.should()
should = chai.should()

# Bring in our Instafeed class
Instafeed = require '../src/instafeed'

# Define our tests
describe 'Instafeed instace', ->
  feed = null
  document = 'test'

  it 'should inherit defaults if nothing is passed', ->
    feed = new Instafeed
    feed.options.target.should.equal 'instafeed'
    feed.options.resolution.should.equal 'thumbnail'

  it 'should accept multiple options as an object', ->
    feed = new Instafeed
      target: 'mydiv'
      clientId: 'mysecretid'
    feed.options.target.should.equal 'mydiv'
    feed.options.clientId.should.equal 'mysecretid'
    feed.options.resolution.should.equal 'thumbnail'

  it 'should accept target as element', ->
    documentMock = {
      createElement: (name) ->
        return {
          appendChild: (fragment) ->
            return
        }
    }
    feed = new Instafeed
      target: documentMock.createElement('div')

  it 'should accept context as a parameter', ->
    context = {}
    feed = new Instafeed({}, context)
    feed.context.should.equal context

  it 'should have a unique timestamp when instantiated', ->
    feed = new Instafeed
    feed.unique.should.exist

  it 'should refuse to run without a feed id', ->
    feed = new Instafeed
    (-> feed.run()).should.throw "Missing feedId. Get it from bitsalad."

  it 'should refuse to parse NON-JSON data', ->
    (-> feed.parse('non-object')).should.throw 'Invalid JSON response'

  it 'should detect when no images are returned from the API', ->
    (-> feed.parse(
      []
    )).should.throw 'No images were returned from bitsalad.co'

  it 'should assemble a url using the client id', ->
    feed = new Instafeed
      feedId: 12
    feed._buildUrl().should.equal "https://api.bitsalad.co/v1/feeds/12?callback=instafeedCache#{feed.unique}.parse"

  it 'should run a before & after callback functions', ->
    timesRan = 0
    callback = ->
      timesRan++

    feed = new Instafeed
      feedId: 1
      before: callback
      after: callback
    feed.run()
    timesRan.should.equal 1

    feed.parse
      meta:
        code: 200
      data: [1,2,3]
    timesRan.should.equal 2

  it 'should run a success callback with json data', ->
    numImages = 0
    callback = (json) ->
      numImages = json.data.length

    feed = new Instafeed
      clientId: 'test'
      success: callback
    feed.parse [1,2,3]

    numImages.should.equal 3

  it 'should run the error callback if problem with json data', ->
    message = ''
    callback = (problem) ->
      message = problem
    feed = new Instafeed
      feedId: 1
      error: callback

    feed.parse 3
    message.should.equal 'Invalid JSON data'

    feed.parse []
    message.should.equal 'No images were returned'

  it 'should ignore special characters in the template data', ->
    feed = new Instafeed
    template = '<div>{{custom.text}}</div>'
    data =
      custom:
        text: 'some /test/ $1900'

    feed._makeTemplate(template, data).should.equal '<div>some /test/ $1900</div>'

  it 'should parse an html template (including nested properties)', ->
    feed = new Instafeed
    template = '<div>{{custom}} - {{nested[0].target}} {hard code}</div>'
    data =
      custom: 'test data'
      nested: [
        {target: 4}
      ]

    feed._makeTemplate('{{doesntexist}}', {}).should.equal ""
    feed._makeTemplate(template, data).should.equal '<div>test data - 4 {hard code}</div>'

  it 'should be able to access a nested object property by a string', ->
    feed = new Instafeed
    test =
      toplevel:
        first: 2
        lowerlevel:
          property: 'test'
      empty: null

    should.equal(feed._getObjectProperty(test, 'toplevel.doesntexist.somekey'), null)
    should.equal(feed._getObjectProperty(null, 'anything.someothing'), null)
    should.equal(feed._getObjectProperty(test, 'empty.key1'), null)
    feed._getObjectProperty(test, 'toplevel[first]').should.equal 2
    feed._getObjectProperty(test, 'toplevel.lowerlevel.property').should.equal 'test'

  it 'should be able to sort data by a property', ->
    feed = new Instafeed
    image1 =
      name: "image1"
      meta:
        likes:
          count: 21
        comments: 14
    image2 =
      name: "image2"
      meta:
        likes:
          count: 1
        comments: 25
    image3 =
      name: "image3"
      meta:
        likes:
          count: 22
        comments: 1
    testdata = [image1, image2, image3]

    feed._sortBy(testdata, 'meta.likes.count', false).should.deep.equal [image3, image1, image2]
    feed._sortBy(testdata, 'meta.likes.count', true).should.deep.equal [image2, image1, image3]
    feed._sortBy(testdata, 'meta.comments', false).should.deep.equal [image2, image1, image3]

  it 'should be able to filter data with a callback', ->
    feed = new Instafeed

    filterFunc = (image) ->
      return image.name is "image1"

    image1 =
      name: "image1"
    image2 =
      name: "image2"
    image3 =
      name: "image3"
    testdata = [image1, image2, image3]

    feed._filter(testdata, filterFunc).should.deep.equal [image1]



