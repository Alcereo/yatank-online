app = angular.module("ng-tank-report", ["angular-rickshaw"])

collect_subtree = (storage, subtree, ts) ->
  for key, node of subtree
    if typeof node is 'number' or typeof node is 'array'
      storage[key].push
        x: ts
        y: node
    else
      collect_subtree(storage[key], node, ts)

collect_stats = (stats) ->
  result = {}
  for statItem in stats
    for metric, value of statItem.metrics
      result[metric] = [] if not result[metric]
      result[metric].push
        x: +statItem.ts
        y: +value
  result

collect_monitoring = (monitoring) ->
  result = {}
  for monItem in monitoring
    for host, hostData of monItem.data
      result[host] = {comment: hostData.comment, metrics: {}} if not result[host]
      for metric, value of hostData.metrics
        subgroup = metric.split("_", 1)
        result[host].metrics[subgroup] = {} if not result[host].metrics[subgroup]
        result[host].metrics[subgroup][metric] = [] if not result[host].metrics[subgroup][metric]
        result[host].metrics[subgroup][metric].push
          x: +monItem.timestamp
          y: +value
  result

collect_quantiles = (data) ->

  result = {
    overall:
      interval_real:
        q: {}
    tagged: {}
  }
  for dataItem in data
    for i in [0...dataItem.overall.interval_real.q.q.length]
      result.overall.interval_real.q[dataItem.overall.interval_real.q.q[i]] = [] if not result.overall.interval_real.q[dataItem.overall.interval_real.q.q[i]]
      result.overall.interval_real.q[dataItem.overall.interval_real.q.q[i]].push
        x: dataItem.ts
        y: dataItem.overall.interval_real.q.value[i]
    for tag, tagData of dataItem.tagged
      result.tagged[tag] = {interval_real: { q: {}}} if not result.tagged[tag]
      
      for i in [0...tagData.interval_real.q.q.length]
        result.tagged[tag].interval_real.q[tagData.interval_real.q.q[i]] = [] if not result.tagged[tag].interval_real.q[tagData.interval_real.q.q[i]]
        result.tagged[tag].interval_real.q[tagData.interval_real.q.q[i]].push
          x: dataItem.ts
          y: tagData.interval_real.q.value[i]
  result

app.controller "TankReport", ($scope, $element) ->
  $scope.status = "Disconnected"
  $scope.data = document.cached_data.data
  $scope.uuid = document.cached_data.uuid
  $scope.updateData = (tankData) ->
    for ts, storages of tankData
      for storage, data of storages
        collect_subtree $scope.data[storage], data, +ts
    $scope.$broadcast 'DataUpdated'
  $scope.buildSeries = () ->
    cache = document.cached_data.data
    if cache.stats and cache.data and cache.monitoring
      overallData = {} # TODO
      taggedData = {} # TODO
      quantilesData = collect_quantiles(cache.data)
      statsData = collect_stats(cache.stats)
      monitoringData = collect_monitoring(cache.monitoring)
    else
      overallData = {}
      taggedData = {}
      quantilesData = {}
      statsData = {}
      monitoringData = {}
      setTimeout((() -> location.reload(true)), 3000)
    areaGraphs = ['CPU', 'Memory']
    # $scope.monitoringData = (
    #   ({
    #     hostname: hostname
    #     groups: ({
    #       name: groupName
    #       features:
    #         palette: 'spectrum14'
    #         hover: {}
    #         xAxis: {}
    #         yAxis: {}
    #         legend:
    #           toggle: true
    #           highlight: true
    #       options:
    #         renderer: if groupName in areaGraphs then 'area' else 'line'
    #       series: ({
    #         name: name
    #         data: data
    #       } for name, data of series)
    #     } for groupName, series of groups)
    #   } for hostname, groups of monitoringData)
    # )
    $scope.monitoringGraphData = ({
        hostname: hostname
        charts: ({
          name: subgroup
          features:
            palette: 'spectrum14'
            hover: {}
            xAxis: {}
            yAxis: {}
            ySecondaryAxis:
              scale: null
            legend:
              toggle: true
              highlight: true
          options:
            renderer: if subgroup in areaGraphs then "area" else "line"
          series: ({
            name: metric
            data: series
          } for metric, series of metrics)
        }) for subgroup, metrics of hostData.metrics
      } for hostname, hostData of monitoringData
    )
    $scope.quantilesGraphData =
      name: "Response time quantiles"
      features:
        palette: 'classic9'
        hover: {}
        xAxis: {}
        yAxis: {}
        legend:
          toggle: true
          highlight: true
      options:
        renderer: 'area'
        stack: false
        height: $element[0].offsetHeight - 45 - 62
      series: ({
        name: name
        data: data
      } for name, data of quantilesData.overall.interval_real.q).sort (a, b) ->
        return if parseFloat(a.name) <= parseFloat(b.name) then 1 else -1
    $scope.rps =
      name: "Requests per second"
      features:
        palette: 'spectrum14'
        hover: {}
        xAxis: {}
        yAxis: {}
        legend:
          toggle: true
          highlight: true
      options:
        renderer: 'line'
      series: [{
            name: "req/s"
            color: "red"
            data: statsData.reqps
          }]

    $scope.protoCodes =
      name: "Protocol return codes"
      features:
        palette: 'spectrum14'
        hover: {}
        xAxis: {}
        yAxis: {}
        legend:
          toggle: true
          highlight: true
      options:
        renderer: 'area'
        stack: true
        height: $element[0].offsetHeight - 45 - 62
      series: ({
        name: name
        data: data
      } for name, data of overallData.http_codes).sort (a, b) ->
        return if parseFloat(a.name) <= parseFloat(b.name) then 1 else -1

    $scope.netCodes =
      name: "Network return codes"
      features:
        palette: 'spectrum14'
        hover: {}
        xAxis: {}
        yAxis: {}
        legend:
          toggle: true
          highlight: true
      options:
        renderer: 'area'
        stack: true
        height: $element[0].offsetHeight - 45 - 62
      series: ({
        name: name
        data: data
      } for name, data of overallData.net_codes).sort (a, b) ->
        return if parseFloat(a.name) <= parseFloat(b.name) then 1 else -1

  $scope.buildSeries()
#
#  conn = new io.connect("http://#{window.location.host}",
#    'reconnection limit' : 1000
#    'max reconnection attempts' : 'Infinity'
#  )
#  setInterval((
#    () ->conn.emit('heartbeat')
#    ), 3000)
#  conn.on 'connect', () =>
#    console.log("Connection opened...")
#    $scope.status = "Connected"
#
#    $scope.$apply()
#
#  conn.on 'disconnect', () =>
#    console.log("Connection closed...")
#    $scope.status = "Disonnected"
#    $scope.$apply()
#  conn.on 'reload', () =>
#    location.reload(true)
#  conn.on 'message', (msg) =>
#    tankData = JSON.parse msg
#    if tankData.uuid and $scope.uuid != tankData.uuid
#      location.reload(true)
#    else
#      $scope.updateData(tankData.data)
