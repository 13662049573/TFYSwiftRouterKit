Pod::Spec.new do |spec|
  spec.name         = 'TFYSwiftRouterKit'
  spec.version      = '2.3.0'
  spec.summary      = 'Swift 6 强类型通用 iOS 组件路由，支持多导航域、双向会话、Deep Link、恢复与测试。'

  spec.description  = <<-DESC
    TFYSwiftRouterKit 是一套面向组件化 iOS 工程的 Swift Concurrency First 通用路由工具。
    它提供强类型 Route/Contract、可配置 Navigation Scope、UIKit 与 SwiftUI Driver、
    Command/Event/Output 双向会话、事务注册、超时取消、Deep Link、状态恢复、组件服务和测试替身。
    路由核心不绑定业务名称、固定 URL、图片、文案或持久化键；产品资源和降级界面均由 App 注入。
    组件根页面同样通过 Route 注册，App 壳无需直接依赖业务 UIViewController。
  DESC

  spec.homepage     = 'https://github.com/13662049573/TFYSwiftRouterKit'
  spec.documentation_url = 'https://github.com/13662049573/TFYSwiftRouterKit/tree/2.3.0#readme'
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author       = { '田风有' => '420144542@qq.com' }
  spec.source       = {
    :git => 'https://github.com/13662049573/TFYSwiftRouterKit.git',
    :tag => spec.version.to_s
  }

  spec.ios.deployment_target = '16.0'
  spec.swift_version = '6.0'
  spec.requires_arc = true
  spec.static_framework = true
  spec.module_name = 'TFYSwiftRouterKit'

  # 子规格与 Package.swift 产品及源码目录一一对应。
  spec.subspec 'Core' do |core|
    core.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/Core/**/*.swift'
    core.frameworks = 'Foundation'
  end

  spec.subspec 'UIKit' do |uikit|
    uikit.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/UIKit/**/*.swift'
    uikit.dependency 'TFYSwiftRouterKit/Core'
    uikit.frameworks = 'UIKit', 'SwiftUI'
  end

  spec.subspec 'SwiftUI' do |swiftui|
    swiftui.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/SwiftUI/**/*.swift'
    swiftui.dependency 'TFYSwiftRouterKit/Core'
    swiftui.frameworks = 'SwiftUI', 'Combine'
  end

  spec.subspec 'DeepLink' do |deep_link|
    deep_link.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/DeepLink/**/*.swift'
    deep_link.dependency 'TFYSwiftRouterKit/Core'
    deep_link.frameworks = 'Foundation'
  end

  spec.subspec 'Restoration' do |restoration|
    restoration.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/Restoration/**/*.swift'
    restoration.dependency 'TFYSwiftRouterKit/Core'
    restoration.frameworks = 'Foundation'
  end

  spec.subspec 'Testing' do |testing|
    testing.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/Testing/**/*.swift'
    testing.dependency 'TFYSwiftRouterKit/Core'
    testing.frameworks = 'Foundation'
  end

  spec.subspec 'Umbrella' do |umbrella|
    umbrella.source_files = 'TFYSwiftRouterKit/TFYSwiftRouter/Umbrella/**/*.swift'
    umbrella.dependency 'TFYSwiftRouterKit/Core'
    umbrella.dependency 'TFYSwiftRouterKit/UIKit'
    umbrella.dependency 'TFYSwiftRouterKit/SwiftUI'
    umbrella.dependency 'TFYSwiftRouterKit/DeepLink'
    umbrella.dependency 'TFYSwiftRouterKit/Restoration'
  end

  # 默认聚合仅包含运行时能力；测试 Target 请显式依赖 TFYSwiftRouterKit/Testing。
  spec.default_subspecs = 'Umbrella'
end
