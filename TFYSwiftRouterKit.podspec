Pod::Spec.new do |spec|
  spec.name         = 'TFYSwiftRouterKit'
  spec.version      = '1.0.0'
  spec.summary      = 'Swift 6 强类型 iOS 组件路由，支持多导航栈、双向会话、Deep Link 与组件服务。'

  spec.description  = <<-DESC
    TFYSwiftRouterKit 是一套面向组件化 iOS 工程的 Swift Concurrency First 路由工具。
    它提供强类型 Route、独立 Navigation Scope、UIKit 与 SwiftUI Driver、完整模型输入、
    Command/Event/Output 双向会话、拦截器、Deep Link、状态恢复、组件服务和测试替身。
    组件根页面同样通过 Route 注册，App 壳无需直接依赖业务 UIViewController。
  DESC

  spec.homepage     = 'https://github.com/13662049573/TFYSwiftRouterKit'
  spec.documentation_url = 'https://github.com/13662049573/TFYSwiftRouterKit#readme'
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

  # Subspecs mirror Package.swift products and source folders one-to-one.
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
    umbrella.dependency 'TFYSwiftRouterKit/Testing'
  end

  spec.default_subspecs = 'Umbrella'
end
